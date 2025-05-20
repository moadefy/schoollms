import 'package:flutter/foundation.dart';

class SyncState extends ChangeNotifier {
  String? _lastSyncTime;
  String? _lastError;

  String? get lastSyncTime => _lastSyncTime;
  String? get lastError => _lastError;

  void updateSyncStatus({String? lastSyncTime, String? error}) {
    _lastSyncTime = lastSyncTime;
    _lastError = error;
    notifyListeners();
  }
}
