import 'package:flutter/material.dart';

class AppMotion {
  static const duration = Duration(milliseconds: 320);
  static const staggerInterval = Duration(milliseconds: 650);
  static const curve = Curves.easeOutCubic;
}

class InitialListEntrance extends StatelessWidget {
  const InitialListEntrance({
    super.key,
    required this.animation,
    required this.index,
    required this.child,
  });

  final Animation<double> animation;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (index >= 4 || MediaQuery.disableAnimationsOf(context)) return child;
    final start = index * 0.16;
    final progress = animation.drive(
      CurveTween(curve: Interval(start, start + 0.52, curve: AppMotion.curve)),
    );
    return FadeTransition(
      opacity: progress,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.035), end: Offset.zero)
            .animate(progress),
        child: child,
      ),
    );
  }
}
