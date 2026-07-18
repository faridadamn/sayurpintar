import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static ConnectivityService? _instance;
  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  ConnectivityService._() {
    _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
  }

  factory ConnectivityService() {
    _instance ??= ConnectivityService._();
    return _instance!;
  }

  Stream<bool> get onConnectivityChanged => _controller.stream;

  void _onConnectivityChanged(ConnectivityResult result) {
    _controller.add(result != ConnectivityResult.none);
  }

  Future<bool> get isConnected async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  void dispose() {
    _controller.close();
  }
}
