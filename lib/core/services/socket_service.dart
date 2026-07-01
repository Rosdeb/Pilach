import 'dart:async';
import 'package:app/core/utils/app_logger.dart';
import 'package:flutter/widgets.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService extends WidgetsBindingObserver {
  IO.Socket? _socket;
  final String baseUrl;
  
  // Expose stream controllers for the app to listen to
  final _newMessageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNewMessage => _newMessageController.stream;

  final _messageEditedController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMessageEdited => _messageEditedController.stream;

  final _userActionController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onUserAction => _userActionController.stream;

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
    });

    _socket!.onAny((event, data) {
      Logger.log('🔍 SOCKET RAW EVENT [$event]: $data');
    });

    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      Logger.log('💓 SOCKET ALIVE CHECK: connected=${_socket?.connected}, id=${_socket?.id}');
    });

    _socket!.on('message:new', (data) {
      Logger.log('SOCKET NEW MESSAGE:  [message:new]: $data');
      if (data != null) {
        Logger.log('SOCKET INCOMING [message:new]: $data');
        _newMessageController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('message:edited', (data) {
      if (data != null) {
        Logger.log(' SOCKET INCOMING [message:edited]: $data');
        _messageEditedController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('user:action', (data) {
      if (data != null) {
        Logger.log('👤 SOCKET INCOMING [user:action]: $data');
        _userActionController.add(Map<String, dynamic>.from(data));
      }
    });
  }

  void _onReconnected() {
    // 1. Flush outbox
    // 2. Trigger gap-fill via SyncEngine (to be implemented)
  }

  void emit(String event, dynamic data) {
    Logger.log('📤 SOCKET EMIT [$event]: $data');
    _socket?.emit(event, data);
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
