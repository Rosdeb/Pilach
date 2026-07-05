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

  SocketService({required this.baseUrl});

  void connect(String token) {
    if (_socket?.connected == true) return;
    Logger.log('🌐 SOCKET: Attempting to connect to $baseUrl...');
    _socket = IO.io(baseUrl, IO.OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': token})
        .setExtraHeaders({
          'Authorization': 'Bearer $token',
          'Cookie': 'access_token=$token',
        })
        .enableReconnection()
        .setReconnectionAttempts(999999)
        .setReconnectionDelay(1000)
        .setReconnectionDelayMax(10000)
        .build());

    _socket!.onConnect((_) {
      Logger.log('Connected');
      _onReconnected();
    });

    _socket!.onDisconnect((_) {
      Logger.log('🔴 SOCKET: Disconnected from server.');
    });

    _socket!.onConnectError((err) {
      Logger.log('⚠️ SOCKET ERROR: $err');
      _handlePotentialAuthError(err);
    });

    _socket!.on('error', (err) {
      Logger.log('⚠️ SOCKET SERVER ERROR: $err');
      _handlePotentialAuthError(err);
    });

    _socket!.onAny((event, data) {
      Logger.log('🔍 SOCKET RAW EVENT [$event]: $data');
    });

    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      final isConnected = _socket?.connected == true;
      final hasId = _socket?.id != null;
      Logger.log('💓 SOCKET ALIVE CHECK: connected=$isConnected, id=${_socket?.id}');
      
      if (!isConnected || !hasId) {
        Logger.log('🔄 SOCKET: Connection dead. Attempting manual reconnect...');
        _socket?.connect();
      }
    });

    // Register all specific event listeners
    _registerListeners();
  }

  void _registerListeners() {
    _socket!.on('presence:online', (data) => _addEvent(_presenceOnlineController, data));
    _socket!.on('presence:offline', (data) => _addEvent(_presenceOfflineController, data));
    _socket!.on('user:typing', (data) => _addEvent(_userTypingController, data));
    
    _socket!.on('message:new', (data) => _addEvent(_newMessageController, data));
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
    if (data != null) {
      controller.add(Map<String, dynamic>.from(data));
    }
  }

  bool _isRefreshing = false;

  Future<void> _handlePotentialAuthError(dynamic err) async {
    if (err == null) return;
    
    final errorStr = err.toString();
    final isUnauthorized = errorStr.contains('Unauthorized') || 
                           errorStr.contains('Invalid or expired token') ||
                           (err is Map && err['message']?.toString().contains('Unauthorized') == true);
                           
    if (isUnauthorized && !_isRefreshing) {
      _isRefreshing = true;
      Logger.log('🔄 SOCKET: Token expired. Attempting to refresh...');
      
      if (onTokenRefreshRequested != null) {
        final newToken = await onTokenRefreshRequested!();
        if (newToken != null && newToken.isNotEmpty) {
          Logger.log('✅ SOCKET: Token refreshed successfully. Reconnecting...');
          // Force disconnect and reconnect with the new token
          _socket?.disconnect();
          connect(newToken);
        } else {
          Logger.log('❌ SOCKET: Token refresh failed.');
        }
      }
      
      _isRefreshing = false;
    }
  }

  void _onReconnected() {
    _reconnectedController.add(null);
  }

  void emit(String event, dynamic data) {
    Logger.log('📤 SOCKET EMIT [$event]: $data');
    _socket?.emit(event, data);
  }

  Future<Map<String, dynamic>> emitWithAck(String event, dynamic data) {
    final completer = Completer<Map<String, dynamic>>();
    Logger.log('📤 SOCKET EMIT_ACK [$event]: $data');
    if (_socket == null || !_socket!.connected) {
      completer.complete({'ok': false, 'error': {'code': 'NOT_CONNECTED', 'message': 'Socket is not connected'}});
      return completer.future;
    }
    
    try {
      // Use socket.io emitWithAck behavior
      _socket!.emitWithAck(event, data, ack: (dynamic response) {
        Logger.log('📥 SOCKET ACK RESPONSE [$event]: $response');
        if (response is Map) {
          completer.complete(Map<String, dynamic>.from(response));
        } else {
           // Fallback if server doesn't return the standard Ack<T> object
          completer.complete({'ok': true, 'data': response});
        }
      });
    } catch (e) {
      completer.complete({'ok': false, 'error': {'code': 'EMIT_ERROR', 'message': e.toString()}});
    }
    
    return completer.future;
  }

  void disconnect() {
    Logger.log('🔌 SOCKET: Manual disconnect called.');
    _statusTimer?.cancel();
    _socket?.disconnect();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_socket?.connected != true) {
        // connect('cached_token_here'); 
      } else {
        _onReconnected(); 
      }
    } else if (state == AppLifecycleState.paused) {
      // Optional: disconnect after a timer to save battery
    }
  }
}
