import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/providers/api_provider.dart';
import '../../../../core/services/socket_service.dart';

enum ConnectionBannerStatus {
  hidden,
  offline,
  connecting,
  reconnecting,
  connected,
}

final connectionBannerProvider =
    StateNotifierProvider.autoDispose<
      ConnectionBannerNotifier,
      ConnectionBannerStatus
    >((ref) {
      final socketService = ref.watch(socketServiceProvider);
      return ConnectionBannerNotifier(socketService);
    });

class ConnectionBannerNotifier extends StateNotifier<ConnectionBannerStatus> {
  final SocketService _socketService;
  Timer? _debounceTimer;
  Timer? _connectedDismissTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<SocketConnectionState>? _socketSub;
  bool _isNetworkOnline = true;
  SocketConnectionState _currentSocketState =
      SocketConnectionState.disconnected;

  ConnectionBannerNotifier(this._socketService)
    : super(ConnectionBannerStatus.hidden) {
    _init();
  }

  Future<void> _init() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _isNetworkOnline = !results.every((r) => r == ConnectivityResult.none);
    } catch (_) {
      _isNetworkOnline = true;
    }

    _currentSocketState = _socketService.connectionState;
    _evaluate(isInitial: true);

    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = !results.every((r) => r == ConnectivityResult.none);
      if (_isNetworkOnline != online) {
        _isNetworkOnline = online;
        _evaluate();
      }
    });

    _socketSub = _socketService.connectionStates.listen((socketState) {
      if (_currentSocketState != socketState) {
        _currentSocketState = socketState;
        _evaluate();
      }
    });
  }

  void _evaluate({bool isInitial = false}) {
    if (!mounted) return;

    // Genuine network loss: show offline immediately
    if (!_isNetworkOnline) {
      _debounceTimer?.cancel();
      _debounceTimer = null;
      _connectedDismissTimer?.cancel();
      state = ConnectionBannerStatus.offline;
      return;
    }

    // Network is online & socket is connected
    if (_currentSocketState == SocketConnectionState.connected) {
      _debounceTimer?.cancel();
      _debounceTimer = null;

      if (state == ConnectionBannerStatus.offline ||
          state == ConnectionBannerStatus.connecting ||
          state == ConnectionBannerStatus.reconnecting) {
        // Transition to connected briefly
        state = ConnectionBannerStatus.connected;
        _connectedDismissTimer?.cancel();
        _connectedDismissTimer = Timer(const Duration(seconds: 2), () {
          if (mounted && state == ConnectionBannerStatus.connected) {
            state = ConnectionBannerStatus.hidden;
          }
        });
      } else if (state != ConnectionBannerStatus.connected) {
        state = ConnectionBannerStatus.hidden;
      }
      return;
    }

    // Network is online, but socket is connecting / reconnecting / disconnected.
    _connectedDismissTimer?.cancel();
    if (isInitial || state == ConnectionBannerStatus.hidden) {
      _debounceTimer ??= Timer(const Duration(milliseconds: 2500), () {
        _debounceTimer = null;
        if (!mounted) return;
        if (!_isNetworkOnline) {
          state = ConnectionBannerStatus.offline;
        } else if (_currentSocketState == SocketConnectionState.connecting ||
            _currentSocketState == SocketConnectionState.disconnected) {
          state = ConnectionBannerStatus.connecting;
        } else if (_currentSocketState == SocketConnectionState.reconnecting) {
          state = ConnectionBannerStatus.reconnecting;
        } else {
          state = ConnectionBannerStatus.hidden;
        }
      });
    } else {
      if (_currentSocketState == SocketConnectionState.reconnecting) {
        state = ConnectionBannerStatus.reconnecting;
      } else {
        state = ConnectionBannerStatus.connecting;
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _connectedDismissTimer?.cancel();
    _connectivitySub?.cancel();
    _socketSub?.cancel();
    super.dispose();
  }
}
