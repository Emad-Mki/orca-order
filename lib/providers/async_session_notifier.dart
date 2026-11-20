import 'package:flutter/foundation.dart';

/// Allows an in-flight request to finish after its session provider is disposed.
mixin AsyncSessionNotifier on ChangeNotifier {
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
