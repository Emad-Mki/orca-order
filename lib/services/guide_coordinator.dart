import 'package:flutter/foundation.dart';

class GuideCoordinator {
  GuideCoordinator._();

  static VoidCallback? _interrupt;
  static bool ready = false;
  static bool get active => _interrupt != null;

  static bool claim(VoidCallback interrupt) {
    if (active) return false;
    _interrupt = interrupt;
    return true;
  }

  static void release(VoidCallback interrupt) {
    if (identical(_interrupt, interrupt)) _interrupt = null;
  }

  static void interrupt() => _interrupt?.call();
}
