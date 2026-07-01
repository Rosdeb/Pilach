import 'dart:async';
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

  Timer? _statusTimer;

  SocketService({required this.baseUrl});

  void connect(String token) {
    if (_socket?.connected == true) return;

    print('🌐 SOCKET: Attempting to connect to $baseUrl...');

    _socket = IO.io(baseUrl, IO.OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': token})
        .setExtraHeaders({
          'Authorization': 'Bearer $token',
          'Cookie': 'access_token=$token',
        })
        .enableReconnection()
        .setReconnectionAttempts(999999) // Practically infinite
        .setReconnectionDelay(1000)
        .setReconnectionDelayMax(10000)
        .build());

    _socket!.onConnect((_) {
      print('🟢 SOCKET: Connected successfully!');
      _onReconnected();
    });

    _socket!.onDisconnect((_) {
      print('🔴 SOCKET: Disconnected from server.');
    });

    _socket!.onConnectError((err) {
      print('⚠️ SOCKET ERROR: $err');
    });

    _socket!.onAny((event, data) {
      print('🔍 SOCKET RAW EVENT [$event]: $data');
    });

    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      print('💓 SOCKET ALIVE CHECK: connected=${_socket?.connected}, id=${_socket?.id}');
    });

    _socket!.on('new', (data) {
      if (data != null) {
        print('📨 SOCKET INCOMING [message:new]: $data');
        _newMessageController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('edited', (data) {
      if (data != null) {
        print('✏️ SOCKET INCOMING [message:edited]: $data');
        _messageEditedController.add(Map<String, dynamic>.from(data));
      }
    });

    // Handle other events: message:read_receipt, etc.
  }

  void _onReconnected() {
    // 1. Flush outbox
    // 2. Trigger gap-fill via SyncEngine (to be implemented)
  }

  void emit(String event, dynamic data) {
    print('📤 SOCKET EMIT [$event]: $data');
    _socket?.emit(event, data);
  }

  void disconnect() {
    print('🔌 SOCKET: Manual disconnect called.');
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
