import 'dart:async';
import 'dart:math';

import 'package:app/core/utils/app_logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

enum SocketConnectionState { connecting, connected, reconnecting, disconnected }

class SocketService extends WidgetsBindingObserver {
  SocketService({required this.baseUrl}) {
    Logger.log(
      'SocketService created — registering lifecycle observer',
      type: 'socket',
    );
    WidgetsBinding.instance.addObserver(this);
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _handleConnectivityChanged,
    );
  }

  socket_io.Socket? _socket;
  final String baseUrl;
  Future<String?> Function()? onTokenRefreshRequested;

  final _connectionStateController =
      StreamController<SocketConnectionState>.broadcast();
  SocketConnectionState _connectionState = SocketConnectionState.disconnected;
  SocketConnectionState get connectionState => _connectionState;
  Stream<SocketConnectionState> get connectionStates =>
      _connectionStateController.stream;

  final _reconnectedController = StreamController<void>.broadcast();
  Stream<void> get onReconnected => _reconnectedController.stream;

  final _presenceOnlineController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onPresenceOnline =>
      _presenceOnlineController.stream;

  final _presenceOfflineController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onPresenceOffline =>
      _presenceOfflineController.stream;

  final Map<String, Map<String, dynamic>> _presenceSnapshot = {};
  List<Map<String, dynamic>> get presenceSnapshot => _presenceSnapshot.values
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);

  final _userTypingController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onUserTyping => _userTypingController.stream;

  final _newMessageController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNewMessage => _newMessageController.stream;

  final _messageUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMessageUpdated =>
      _messageUpdatedController.stream;

  final _messageDeletedController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMessageDeleted =>
      _messageDeletedController.stream;

  final _messagePinnedController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMessagePinned =>
      _messagePinnedController.stream;

  final _messageUnpinnedController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMessageUnpinned =>
      _messageUnpinnedController.stream;

  final _messageReactionUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMessageReactionUpdated =>
      _messageReactionUpdatedController.stream;

  final _messageReadReceiptController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMessageReadReceipt =>
      _messageReadReceiptController.stream;

  final _messageDeliveredController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMessageDelivered =>
      _messageDeliveredController.stream;

  final _chatUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onChatUpdated =>
      _chatUpdatedController.stream;

  final _chatAddedController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onChatAdded => _chatAddedController.stream;

  final _memberUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMemberUpdated =>
      _memberUpdatedController.stream;

  final _memberRemovedController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMemberRemoved =>
      _memberRemovedController.stream;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _healthTimer;
  Timer? _reconnectTimer;
  Timer? _connectionTimeoutTimer;
  Timer? _presenceHeartbeatTimer;
  String? _token;
  bool _isRefreshing = false;
  bool _isConnecting = false;
  bool _shouldBeConnected = false;
  bool _isSuspended = false;
  bool _presenceVisible = true;
  bool _disposed = false;
  bool _refreshAttemptedForCurrentToken = false;
  int _reconnectAttempt = 0;

  bool get isConnected => _socket?.connected == true;

  /// Publishes the user's active-status preference without disconnecting chat.
  /// The server must honor `presence:visibility` when broadcasting presence.
  void setPresenceVisibility(bool visible) {
    if (_presenceVisible == visible) return;
    _presenceVisible = visible;
    _presenceHeartbeatTimer?.cancel();

    if (!isConnected) return;
    _socket?.emit('presence:visibility', {'visible': visible});
    if (visible) {
      _startPresenceHeartbeat();
    }
    Logger.log('Presence visibility changed: $visible', type: 'socket');
  }

  /// True once we have had at least one successful connection with the
  /// current token. Used to distinguish a first-time connect from a
  /// reconnect so listeners do not receive a spurious "reconnected" event
  /// on initial login.
  bool _hasConnectedOnce = false;

  // ─── Public API ────────────────────────────────────────────────────────────

  void connect(String token) {
    if (_disposed || token.isEmpty) return;

    final tokenChanged = _token != token;
    _token = token;
    _shouldBeConnected = true;
    _isSuspended = false;

    if (tokenChanged) {
      Logger.log(
        'connect() called — token changed, opening fresh socket',
        type: 'socket',
      );
      _refreshAttemptedForCurrentToken = false;
      _reconnectAttempt = 0;
      _disposeCurrentSocket();
    } else if (isConnected || _isConnecting || _isRefreshing) {
      Logger.log(
        'connect() skipped — already ${isConnected
            ? "connected"
            : _isConnecting
            ? "connecting"
            : "refreshing"}',
        type: 'socket',
      );
      return;
    } else {
      Logger.log(
        'connect() called — same token, opening socket',
        type: 'socket',
      );
    }

    _openSocket(isReconnect: _reconnectAttempt > 0);
  }

  final Set<String> _foregroundRooms = {};
  final Set<String> _subscribedRooms = {};

  Set<String> get _activeRooms => {..._subscribedRooms, ..._foregroundRooms};

  void joinConversation(String conversationId) {
    if (conversationId.isEmpty) return;
    _foregroundRooms.add(conversationId);
    Logger.log('Joining conversation room: $conversationId', type: 'socket');
    emit('conversation:join', {'conversationId': conversationId});
  }

  void leaveConversation(String conversationId) {
    _foregroundRooms.remove(conversationId);
    if (!_subscribedRooms.contains(conversationId)) {
      emit('conversation:leave', {'conversationId': conversationId});
    }
  }

  void syncConversationSubscriptions(Iterable<String> conversationIds) {
    final next = conversationIds.where((id) => id.isNotEmpty).toSet();
    final added = next.difference(_subscribedRooms);
    final removed = _subscribedRooms.difference(next);
    _subscribedRooms
      ..clear()
      ..addAll(next);

    if (!isConnected) return;
    for (final roomId in added) {
      _socket?.emit('conversation:join', {'conversationId': roomId});
    }
    for (final roomId in removed) {
      if (!_foregroundRooms.contains(roomId)) {
        _socket?.emit('conversation:leave', {'conversationId': roomId});
      }
    }
    _emitPresenceHeartbeat();
  }

  void forceReconnect() {
    if (_disposed || _token == null || _token!.isEmpty) return;
    Logger.log(
      'forceReconnect() called — cycling socket to sync all rooms',
      type: 'socket',
    );
    _disposeCurrentSocket();
    _reconnectAttempt = 0;
    _openSocket(isReconnect: true);
  }

  void disconnect() {
    Logger.log(
      'disconnect() called — tearing down socket intentionally',
      type: 'socket',
    );
    _shouldBeConnected = false;
    _isSuspended = false;
    _token = null;
    _refreshAttemptedForCurrentToken = false;
    _hasConnectedOnce = false;
    _stopConnection();
  }

  void emit(String event, dynamic data) {
    if (!isConnected) {
      Logger.log('emit() skipped — not connected: [$event]', type: 'warning');
      return;
    }
    _socket?.emit(event, data);
  }

  Future<Map<String, dynamic>> emitWithAck(
    String event,
    dynamic data, {
    Duration timeout = const Duration(seconds: 12),
  }) {
    final completer = Completer<Map<String, dynamic>>();
    if (!isConnected) {
      Logger.log(
        'emitWithAck() skipped — not connected: [$event]',
        type: 'warning',
      );
      return Future.value({
        'ok': false,
        'error': {
          'code': 'NOT_CONNECTED',
          'message': 'Socket is not connected',
        },
      });
    }

    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        Logger.log(
          'emitWithAck() ACK timeout for [$event] after ${timeout.inSeconds}s',
          type: 'warning',
        );
        completer.complete({
          'ok': false,
          'error': {
            'code': 'ACK_TIMEOUT',
            'message': 'Socket acknowledgement timed out',
          },
        });
      }
    });

    try {
      _socket!.emitWithAck(
        event,
        data,
        ack: (dynamic response) {
          if (completer.isCompleted) return;
          timer.cancel();
          if (response is Map) {
            completer.complete(Map<String, dynamic>.from(response));
          } else {
            completer.complete({'ok': true, 'data': response});
          }
        },
      );
    } catch (error) {
      timer.cancel();
      Logger.log('emitWithAck() threw for [$event]: $error', type: 'error');
      if (!completer.isCompleted) {
        completer.complete({
          'ok': false,
          'error': {'code': 'EMIT_ERROR', 'message': error.toString()},
        });
      }
    }
    return completer.future;
  }

  // ─── Internal socket lifecycle ─────────────────────────────────────────────

  void _openSocket({required bool isReconnect}) {
    final token = _token;
    if (_disposed ||
        token == null ||
        token.isEmpty ||
        !_shouldBeConnected ||
        _isSuspended ||
        _isConnecting ||
        isConnected) {
      Logger.log(
        '_openSocket() aborted — '
        'disposed=$_disposed suspended=$_isSuspended '
        'connecting=$_isConnecting connected=$isConnected',
        type: 'socket',
      );
      return;
    }

    _reconnectTimer?.cancel();
    _connectionTimeoutTimer?.cancel();
    _isConnecting = true;
    _setConnectionState(
      isReconnect
          ? SocketConnectionState.reconnecting
          : SocketConnectionState.connecting,
    );

    Logger.log(
      '_openSocket() → ${isReconnect ? "RECONNECT attempt #$_reconnectAttempt" : "INITIAL connect"} to $baseUrl',
      type: 'socket',
    );

    final socket = socket_io.io(
      baseUrl,
      socket_io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .setExtraHeaders({
            'Authorization': 'Bearer $token',
            'Cookie': 'access_token=$token',
          })
          .disableAutoConnect()
          .disableReconnection()
          .enableForceNew()
          .build(),
    );
    _socket = socket;

    _connectionTimeoutTimer = Timer(const Duration(seconds: 12), () {
      if (!identical(_socket, socket) || isConnected) return;
      Logger.log(
        'Connection attempt timed out — resetting socket and retrying',
        type: 'socket',
      );
      _disposeCurrentSocket();
      _setConnectionState(SocketConnectionState.disconnected);
      _scheduleReconnect();
    });

    socket.onConnect((_) {
      if (!identical(_socket, socket)) return;
      _connectionTimeoutTimer?.cancel();
      _connectionTimeoutTimer = null;
      _isConnecting = false;
      _isRefreshing = false;
      _refreshAttemptedForCurrentToken = false;
      final wasReconnect = _hasConnectedOnce;
      _hasConnectedOnce = true;
      _reconnectAttempt = 0;
      _setConnectionState(SocketConnectionState.connected);
      Logger.log(
        'CONNECTED ✅  id=${socket.id}  ${wasReconnect ? "(reconnect — firing onReconnected)" : "(initial connect)"}',
        type: 'socket',
      );
      _startHealthCheck();
      socket.emit('presence:visibility', {'visible': _presenceVisible});
      if (_presenceVisible) _startPresenceHeartbeat();

      // Re-emit room join events for active rooms
      for (final roomId in _activeRooms) {
        socket.emit('conversation:join', {'conversationId': roomId});
      }

      // Only fire onReconnected for genuine reconnects, not the first login.
      if (wasReconnect && !_reconnectedController.isClosed) {
        _reconnectedController.add(null);
      }
    });

    socket.onDisconnect((reason) {
      if (!identical(_socket, socket)) return;
      _connectionTimeoutTimer?.cancel();
      _connectionTimeoutTimer = null;
      _isConnecting = false;
      _healthTimer?.cancel();
      _setConnectionState(SocketConnectionState.disconnected);
      Logger.log('DISCONNECTED 🔴  reason="$reason"', type: 'socket');
      _scheduleReconnect();
    });

    socket.onConnectError((error) {
      if (!identical(_socket, socket)) return;
      _connectionTimeoutTimer?.cancel();
      _connectionTimeoutTimer = null;
      _isConnecting = false;
      _setConnectionState(SocketConnectionState.disconnected);
      Logger.log('CONNECT ERROR ⚠️  $error', type: 'socket');
      if (!_isAuthError(error)) _scheduleReconnect();
      unawaited(_handlePotentialAuthError(error));
    });

    socket.on('error', (error) {
      if (!identical(_socket, socket)) return;
      Logger.log('SERVER ERROR ⚠️  $error', type: 'socket');
      unawaited(_handlePotentialAuthError(error));
    });

    socket.onAny((event, data) {
      if (event != 'error' && event != 'connect' && event != 'disconnect') {
        Logger.log('RAW EVENT [$event]: $data');
      }
    });

    _registerListeners(socket);
    socket.connect();
  }

  void _registerListeners(socket_io.Socket socket) {
    void listen(
      String event,
      StreamController<Map<String, dynamic>> controller,
    ) {
      socket.on(event, (data) => _addEvent(controller, data, event));
    }

    socket.on(
      'presence:online',
      (data) => _handlePresenceEvent(
        data,
        isOnline: true,
        controller: _presenceOnlineController,
      ),
    );
    socket.on(
      'presence:offline',
      (data) => _handlePresenceEvent(
        data,
        isOnline: false,
        controller: _presenceOfflineController,
      ),
    );

    listen('user:action', _userTypingController);
    listen('user:typing', _userTypingController);
    listen('message:typing', _userTypingController);

    listen('message:new', _newMessageController);
    listen('message:edited', _messageUpdatedController);
    listen('message:updated', _messageUpdatedController);
    listen('message:deleted', _messageDeletedController);
    listen('message:pinned', _messagePinnedController);
    listen('message:unpinned', _messageUnpinnedController);
    listen('message:reacted', _messageReactionUpdatedController);
    listen('message:reaction_updated', _messageReactionUpdatedController);
    listen('message:read_receipt', _messageReadReceiptController);
    listen('message:delivered', _messageDeliveredController);
    listen('chat:updated', _chatUpdatedController);
    listen('chat:added', _chatAddedController);
    listen('member:updated', _memberUpdatedController);
    listen('member:removed', _memberRemovedController);

    Logger.log(
      'Listeners registered for ${socket.id ?? "pending"}',
      type: 'socket',
    );
  }

  void _addEvent(
    StreamController<Map<String, dynamic>> controller,
    dynamic data,
    String event,
  ) {
    if (controller.isClosed) return;
    if (data is Map) {
      controller.add(Map<String, dynamic>.from(data));
    } else {
      Logger.log(
        'Ignoring malformed socket event [$event] — expected Map, got ${data.runtimeType}',
        type: 'warning',
      );
    }
  }

  void _handlePresenceEvent(
    dynamic data, {
    required bool isOnline,
    required StreamController<Map<String, dynamic>> controller,
  }) {
    if (data is! Map) {
      Logger.log(
        'Ignoring malformed presence event: ${data.runtimeType}',
        type: 'warning',
      );
      return;
    }
    final event = Map<String, dynamic>.from(data);
    final payload = event['data'] is Map
        ? Map<String, dynamic>.from(event['data'] as Map)
        : event;
    final user = payload['user'] is Map
        ? Map<String, dynamic>.from(payload['user'] as Map)
        : const <String, dynamic>{};
    final rawUserId =
        payload['userId'] ??
        payload['user_id'] ??
        payload['id'] ??
        user['id'] ??
        user['_id'];
    final userId = rawUserId?.toString().trim();
    if (userId != null && userId.isNotEmpty) {
      final lastSeen =
          payload['lastSeen'] ??
          payload['lastActive'] ??
          user['lastSeen'] ??
          user['lastActive'];
      final snapshot = <String, dynamic>{
        'userId': userId,
        'isOnline': isOnline,
      };
      if (lastSeen != null) snapshot['lastSeen'] = lastSeen;
      _presenceSnapshot[userId] = snapshot;
    }
    if (!controller.isClosed) controller.add(event);
  }

  // ─── Health check & reconnect backoff ──────────────────────────────────────

  void _startHealthCheck() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!isConnected && !_isConnecting && !_isRefreshing) {
        Logger.log(
          'Health-check: socket not connected — scheduling immediate reconnect',
          type: 'socket',
        );
        _scheduleReconnect(immediate: true);
      }
    });
  }

  void _startPresenceHeartbeat() {
    _presenceHeartbeatTimer?.cancel();
    if (!_presenceVisible) return;
    _emitPresenceHeartbeat();
    _presenceHeartbeatTimer = Timer.periodic(
      const Duration(seconds: 25),
      (_) => _emitPresenceHeartbeat(),
    );
  }

  void _emitPresenceHeartbeat() {
    if (!isConnected || !_presenceVisible) return;
    _socket?.emit('presence:heartbeat', <String, dynamic>{});
  }

  void _scheduleReconnect({bool immediate = false}) {
    if (_disposed ||
        !_shouldBeConnected ||
        _isSuspended ||
        _isRefreshing ||
        _token == null ||
        _reconnectTimer?.isActive == true) {
      return;
    }

    final delaySeconds = immediate
        ? 0
        : min(30, 1 << min(_reconnectAttempt, 5));
    _reconnectAttempt++;
    _setConnectionState(SocketConnectionState.reconnecting);
    Logger.log(
      'Reconnect scheduled — attempt #$_reconnectAttempt in ${delaySeconds}s',
      type: 'socket',
    );
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _openSocket(isReconnect: true);
    });
  }

  // ─── Connectivity ──────────────────────────────────────────────────────────

  void _handleConnectivityChanged(List<ConnectivityResult> results) {
    final online = !results.every((r) => r == ConnectivityResult.none);
    Logger.log(
      'Connectivity changed → ${online ? results.map((r) => r.name).join(", ") : "OFFLINE"}',
      type: 'socket',
    );

    if (!online) {
      _reconnectTimer?.cancel();
      _disposeCurrentSocket();
      _setConnectionState(SocketConnectionState.disconnected);
      return;
    }

    if (_shouldBeConnected && !isConnected && !_isSuspended) {
      Logger.log(
        'Network restored — triggering immediate reconnect',
        type: 'socket',
      );
      _reconnectTimer?.cancel();
      _openSocket(isReconnect: true);
    }
  }

  // ─── Auth error / token refresh ────────────────────────────────────────────

  bool _isAuthError(dynamic error) {
    final message = error is Map
        ? (error['message'] ?? error['error'] ?? '').toString()
        : error?.toString() ?? '';
    final normalized = message.toLowerCase();
    return normalized.contains('unauthorized') ||
        normalized.contains('invalid or expired token') ||
        normalized.contains('token expired') ||
        normalized.contains('authentication error');
  }

  Future<void> _handlePotentialAuthError(dynamic error) async {
    if (!_isAuthError(error) ||
        _isRefreshing ||
        _refreshAttemptedForCurrentToken ||
        _disposed) {
      return;
    }

    Logger.log(
      'Auth error detected — attempting token refresh',
      type: 'socket',
    );
    _refreshAttemptedForCurrentToken = true;
    _isRefreshing = true;
    _reconnectTimer?.cancel();
    _healthTimer?.cancel();
    _disposeCurrentSocket();
    _setConnectionState(SocketConnectionState.disconnected);

    try {
      final refreshedToken = await onTokenRefreshRequested?.call();
      _isRefreshing = false;
      if (refreshedToken != null && refreshedToken.isNotEmpty) {
        Logger.log('Token refreshed — reconnecting socket', type: 'socket');
        _token = null; // Force connect() to treat this as a new token
        connect(refreshedToken);
      } else {
        Logger.log(
          'Token refresh returned no new token — socket stays down',
          type: 'socket',
        );
      }
    } catch (e) {
      _isRefreshing = false;
      Logger.log('Token refresh threw: $e', type: 'error');
    }
  }

  // ─── Internal teardown helpers ─────────────────────────────────────────────

  void _suspendConnection() {
    if (!_shouldBeConnected) return;
    _isSuspended = true;
    Logger.log('Connection suspended (app backgrounded)', type: 'socket');
    _stopConnection();
  }

  void _stopConnection() {
    _reconnectTimer?.cancel();
    _healthTimer?.cancel();
    _presenceHeartbeatTimer?.cancel();
    _isConnecting = false;
    _isRefreshing = false;
    _disposeCurrentSocket();
    _setConnectionState(SocketConnectionState.disconnected);
  }

  void _disposeCurrentSocket() {
    _connectionTimeoutTimer?.cancel();
    _connectionTimeoutTimer = null;
    _presenceHeartbeatTimer?.cancel();
    _isConnecting = false;
    final socket = _socket;
    _socket = null;
    if (socket == null) return;
    try {
      socket.dispose();
      socket.destroy();
    } catch (_) {}
    Logger.log('Socket instance disposed', type: 'socket');
  }

  void _setConnectionState(SocketConnectionState next) {
    if (_connectionState == next) return;
    final prev = _connectionState;
    _connectionState = next;
    Logger.log(
      'State: ${prev.name.toUpperCase()} → ${next.name.toUpperCase()}',
      type: 'socket',
    );
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(next);
    }
  }

  // ─── App lifecycle ─────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        Logger.log(
          'APP RESUMED — socket=${isConnected ? "connected" : "disconnected"} suspended=$_isSuspended shouldConnect=$_shouldBeConnected',
          type: 'lifecycle',
        );
        _isSuspended = false;
        if (_shouldBeConnected && !isConnected) {
          Logger.log(
            'APP RESUMED → socket was down, reconnecting now',
            type: 'lifecycle',
          );
          _reconnectTimer?.cancel();
          _openSocket(isReconnect: true);
        } else if (isConnected) {
          Logger.log(
            'APP RESUMED → socket already connected, no action needed',
            type: 'lifecycle',
          );
        }
        break;

      case AppLifecycleState.inactive:
        Logger.log(
          'APP INACTIVE — short interruption (call/notification), keeping socket alive',
          type: 'lifecycle',
        );
        break;

      case AppLifecycleState.paused:
        Logger.log(
          'APP PAUSED — going to background, suspending socket & marking presence offline',
          type: 'lifecycle',
        );
        _suspendConnection();
        break;

      case AppLifecycleState.hidden:
        Logger.log('APP HIDDEN — suspending socket', type: 'lifecycle');
        _suspendConnection();
        break;

      case AppLifecycleState.detached:
        Logger.log(
          'APP DETACHED — engine detached, suspending socket',
          type: 'lifecycle',
        );
        _suspendConnection();
        break;
    }
  }

  // ─── Dispose ───────────────────────────────────────────────────────────────

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    Logger.log(
      'SocketService disposing — removing observer & closing all streams',
      type: 'socket',
    );
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_connectivitySubscription?.cancel());
    _shouldBeConnected = false;
    _stopConnection();
    _connectionStateController.close();
    _reconnectedController.close();
    _presenceOnlineController.close();
    _presenceOfflineController.close();
    _userTypingController.close();
    _newMessageController.close();
    _messageUpdatedController.close();
    _messageDeletedController.close();
    _messagePinnedController.close();
    _messageUnpinnedController.close();
    _messageReactionUpdatedController.close();
    _messageReadReceiptController.close();
    _messageDeliveredController.close();
    _chatUpdatedController.close();
    _chatAddedController.close();
    _memberUpdatedController.close();
    _memberRemovedController.close();
    Logger.log('SocketService disposed ✓', type: 'socket');
  }
}
