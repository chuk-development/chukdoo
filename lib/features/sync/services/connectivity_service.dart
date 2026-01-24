import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service for monitoring network connectivity.
/// Provides stream of connectivity changes for adaptive sync.
class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  List<ConnectivityResult> _currentStatus = [ConnectivityResult.none];
  final _statusController = StreamController<bool>.broadcast();

  /// Whether device currently has network connectivity
  bool get isConnected =>
      _currentStatus.isNotEmpty &&
      !_currentStatus.every((r) => r == ConnectivityResult.none);

  /// Stream of connectivity changes (true = connected, false = disconnected)
  Stream<bool> get onConnectivityChanged => _statusController.stream;

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    try {
      _currentStatus = await _connectivity.checkConnectivity();
      debugPrint('ConnectivityService: Initial status: $_currentStatus (connected: $isConnected)');

      _subscription = _connectivity.onConnectivityChanged.listen((result) {
        final wasConnected = isConnected;
        _currentStatus = result;
        final nowConnected = isConnected;

        if (wasConnected != nowConnected) {
          debugPrint('ConnectivityService: Connectivity changed: $nowConnected');
          _statusController.add(nowConnected);
        }
      });
    } catch (e) {
      debugPrint('ConnectivityService: Failed to initialize: $e');
      // Assume connected if we can't check
      _currentStatus = [ConnectivityResult.wifi];
    }
  }

  /// Check current connectivity (force refresh)
  Future<bool> checkConnectivity() async {
    try {
      _currentStatus = await _connectivity.checkConnectivity();
      return isConnected;
    } catch (e) {
      debugPrint('ConnectivityService: Error checking connectivity: $e');
      return true; // Assume connected on error
    }
  }

  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}
