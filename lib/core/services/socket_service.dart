import 'dart:async';
import 'package:app/core/utils/app_logger.dart';
import 'package:flutter/widgets.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService extends WidgetsBindingObserver {
  IO.Socket? _socket;
  final String baseUrl;

  // Callback for automatic token refresh
  Future<String?> Function()? onTokenRefreshRequested;

  // Reconnection Stream
  final _reconnectedController = StreamController<void>.broadcast();
  Stream<void> get onReconnected => _reconnectedController.stream;

  // Presence & Typing
  final _presenceOnlineController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onPresenceOnline => _presenceOnlineController.stream;

  final _presenceOfflineController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onPresenceOffline => _presenceOfflineController.stream;

  final _userTypingController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onUserTyping => _userTypingController.stream;

  // Messages
  final _newMessageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNewMessage => _newMessageController.stream;

  final _messageUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMessageUpdated => _messageUpdatedController.stream;

  final _messageDeletedController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMessageDeleted => _messageDeletedController.stream;

  final _messagePinnedController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMessagePinned => _messagePinnedController.stream;

  final _messageUnpinnedController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMessageUnpinned => _messageUnpinnedController.stream;

  final _messageReactionUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMessageReactionUpdated => _messageReactionUpdatedController.stream;

  final _messageReadReceiptController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMessageReadReceipt => _messageReadReceiptController.stream;

  final _messageDeliveredController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMessageDelivered => _messageDeliveredController.stream;

  // Chat & Members
  final _chatUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onChatUpdated => _chatUpdatedController.stream;

  final _chatAddedController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onChatAdded => _chatAddedController.stream;

  final _memberUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMemberUpdated => _memberUpdatedController.stream;

  final _memberRemovedController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMemberRemoved => _memberRemovedController.stream;

  Timer? _statusTimer;

  // ─── Race condition guards ───────────────────────────────────────────────
  // এই দুটো flag না থাকলে infinite loop হয়:
  // alive check → reconnect → error → refresh → reconnect → alive check → ...
  bool _isRefreshing = false;   // token refresh চলছে
  bool _isConnecting = false;   // connect() call চলছে (not yet established)

  SocketService({required this.baseUrl});

  bool get isConnected => _socket?.connected == true;

  void connect(String token) {
    // ── Guard: একসাথে দুটো connect attempt হবে না ───────────────────────
    if (_socket?.connected == true) {
      Logger.log('⚡ SOCKET: Already connected, skip.');
      return;
    }
    if (_isConnecting) {
      Logger.log('⚡ SOCKET: Connection already in progress, skip.');
      return;
    }
    if (_isRefreshing) {
      Logger.log('⚡ SOCKET: Token refresh in progress, skip connect.');
      return;
    }

    _isConnecting = true;
    Logger.log('🌐 SOCKET: Attempting to connect to $baseUrl...');

    // পুরনো socket থাকলে destroy করো
    _socket?.destroy();

    _socket = IO.io(baseUrl, IO.OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': token})
        .setExtraHeaders({
          'Authorization': 'Bearer $token',
          'Cookie': 'access_token=$token',
        })
        .disableAutoConnect()          // manual connect করব
        .disableReconnection() // socket.io auto-reconnect বন্ধ — আমরা নিজে handle করব
        .enableForceNew()
        .enableMultiplex()
        .build());

    _socket!.onConnect((_) {
      _isConnecting = false;
      Logger.log('✅ SOCKET: Connected! id=${_socket?.id}');
      _startAliveCheck();             // connect হলে alive check শুরু
      _onReconnected();
    });

    _socket!.onDisconnect((_) {
      _isConnecting = false;
      Logger.log('🔴 SOCKET: Disconnected.');
    });

    _socket!.onConnectError((err) {
      _isConnecting = false;
      Logger.log('⚠️ SOCKET CONNECT ERROR: $err');
      _handlePotentialAuthError(err);
    });

    // 'error' event — multiple times আসতে পারে, guard দিয়ে handle করো
    _socket!.on('error', (err) {
      Logger.log('⚠️ SOCKET SERVER ERROR: $err');
      _handlePotentialAuthError(err);
    });

    _socket!.onAny((event, data) {
      // error, connect, disconnect — এগুলো already handled
      if (event != 'error' && event != 'connect' && event != 'disconnect') {
        Logger.log('🔍 SOCKET RAW EVENT [$event]: $data');
      }
    });

    // Register event listeners before connect
    _registerListeners();

    // Now connect
    _socket!.connect();
  }

  void _startAliveCheck() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      // ── যদি refresh বা connect চলছে, touch করো না ──────────────────────
      if (_isRefreshing || _isConnecting) {
        Logger.log('💓 SOCKET ALIVE CHECK: skipped (refresh/connect in progress)');
        return;
      }

      final isConnected = _socket?.connected == true;
      Logger.log('💓 SOCKET ALIVE CHECK: connected=$isConnected, id=${_socket?.id}');

      if (!isConnected) {
        Logger.log('🔄 SOCKET: Connection dead. Attempting reconnect...');
        // Exponential backoff ছাড়া simple reconnect
        _socket?.connect();
      }
    });
  }

  void _registerListeners() {
    _socket!.on('presence:online', (data) => _addEvent(_presenceOnlineController, data));
    _socket!.on('presence:offline', (data) => _addEvent(_presenceOfflineController, data));

    _socket!.on('user:typing', (data) {
      Logger.log('⌨️ SOCKET [user:typing]: $data');
      _addEvent(_userTypingController, data);
    });
    _socket!.on('message:typing', (data) {
      Logger.log('⌨️ SOCKET [message:typing]: $data');
      _addEvent(_userTypingController, data);
    });

    _socket!.on('message:new', (data) {
      Logger.log('📨 SOCKET [message:new]: $data');
      _addEvent(_newMessageController, data);
    });
    _socket!.on('message:updated', (data) => _addEvent(_messageUpdatedController, data));
    _socket!.on('message:deleted', (data) => _addEvent(_messageDeletedController, data));
    _socket!.on('message:pinned', (data) => _addEvent(_messagePinnedController, data));
    _socket!.on('message:unpinned', (data) => _addEvent(_messageUnpinnedController, data));
    _socket!.on('message:reaction_updated', (data) => _addEvent(_messageReactionUpdatedController, data));
    _socket!.on('message:read_receipt', (data) => _addEvent(_messageReadReceiptController, data));
    _socket!.on('message:delivered', (data) => _addEvent(_messageDeliveredController, data));

    _socket!.on('chat:updated', (data) => _addEvent(_chatUpdatedController, data));
    _socket!.on('chat:added', (data) => _addEvent(_chatAddedController, data));

    _socket!.on('member:updated', (data) => _addEvent(_memberUpdatedController, data));
    _socket!.on('member:removed', (data) => _addEvent(_memberRemovedController, data));
  }

  void _addEvent(StreamController<Map<String, dynamic>> controller, dynamic data) {
    if (data != null && !controller.isClosed) {
      controller.add(Map<String, dynamic>.from(data));
    }
  }

  Future<void> _handlePotentialAuthError(dynamic err) async {
    if (err == null) return;

    // ── ইতিমধ্যে refresh চলছে → ignore করো ─────────────────────────────
    if (_isRefreshing) {
      Logger.log('⚡ Auth error received but refresh already in progress — ignored');
      return;
    }

    final errorStr = err.toString();
    final isUnauthorized = errorStr.contains('Unauthorized') ||
                           errorStr.contains('Invalid or expired token') ||
                           (err is Map &&
                               (err['message']?.toString().contains('Unauthorized') == true ||
                                err['message']?.toString().contains('Invalid or expired token') == true));

    if (!isUnauthorized) return;

    _isRefreshing = true;
    // Alive check pause করো এবং পুরাতন expired socket disconnect করো
    _statusTimer?.cancel();
    _statusTimer = null;
    try {
      _socket?.disconnect();
      _socket?.dispose();
    } catch (_) {}
    _socket = null;

    Logger.log('🔄 SOCKET: Token expired — attempting refresh...');

    try {
      if (onTokenRefreshRequested != null) {
        final newToken = await onTokenRefreshRequested!();
        if (newToken != null && newToken.isNotEmpty) {
          Logger.log('✅ SOCKET: Token refreshed. Reconnecting with new token...');
          _isRefreshing = false;     // reset আগে
          _isConnecting = false;     // reset আগে
          connect(newToken);         // fresh connect with new token
        } else {
          Logger.log('❌ SOCKET: Token refresh failed — no new token.');
          _isRefreshing = false;
        }
      } else {
        Logger.log('❌ SOCKET: No token refresh callback registered.');
        _isRefreshing = false;
      }
    } catch (e) {
      Logger.log('❌ SOCKET: Token refresh threw error: $e');
      _isRefreshing = false;
    }
  }

  void _onReconnected() {
    _reconnectedController.add(null);
  }

  void emit(String event, dynamic data) {
    if (_socket?.connected != true) {
      Logger.log('⚠️ SOCKET EMIT skipped (not connected): [$event]');
      return;
    }
    Logger.log('📤 SOCKET EMIT [$event]: $data');
    _socket?.emit(event, data);
  }

  Future<Map<String, dynamic>> emitWithAck(String event, dynamic data) {
    final completer = Completer<Map<String, dynamic>>();
    Logger.log('📤 SOCKET EMIT_ACK [$event]: $data');

    if (_socket == null || !_socket!.connected) {
      completer.complete({
        'ok': false,
        'error': {'code': 'NOT_CONNECTED', 'message': 'Socket is not connected'},
      });
      return completer.future;
    }

    try {
      _socket!.emitWithAck(event, data, ack: (dynamic response) {
        Logger.log('📥 SOCKET ACK [$event]: $response');
        if (response is Map) {
          completer.complete(Map<String, dynamic>.from(response));
        } else {
          completer.complete({'ok': true, 'data': response});
        }
      });
    } catch (e) {
      completer.complete({
        'ok': false,
        'error': {'code': 'EMIT_ERROR', 'message': e.toString()},
      });
    }

    return completer.future;
  }

  void disconnect() {
    Logger.log('🔌 SOCKET: Manual disconnect.');
    _statusTimer?.cancel();
    _statusTimer = null;
    _isRefreshing = false;
    _isConnecting = false;
    _socket?.disconnect();
    _socket?.destroy();
    _socket = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_socket?.connected != true && !_isRefreshing && !_isConnecting) {
        Logger.log('📱 App resumed — socket not connected, attempting reconnect...');
        _socket?.connect();
      } else if (_socket?.connected == true) {
        _onReconnected();
      }
    }
    // paused: socket.io auto-manages reconnection
  }
}
