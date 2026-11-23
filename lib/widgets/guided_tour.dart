import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

import '../services/app_update_service.dart';
import '../services/deep_link_service.dart';
import '../services/guide_coordinator.dart';

typedef GuideTarget = Widget Function(
    int index, String description, Widget child);

class GuidedTour extends StatefulWidget {
  const GuidedTour({
    super.key,
    required this.accountId,
    required this.name,
    required this.targetCount,
    required this.ready,
    required this.builder,
    this.replay = 0,
    this.canStart,
  });

  final String? accountId;
  final String name;
  final int targetCount;
  final bool ready;
  final int replay;
  final bool Function()? canStart;
  final Widget Function(BuildContext, GuideTarget) builder;

  @override
  State<GuidedTour> createState() => _GuidedTourState();
}

class _GuidedTourState extends State<GuidedTour> {
  static int _nextScope = 0;
  late final String _scope = 'guide-${_nextScope++}';
  late final List<GlobalKey> _keys =
      List.generate(widget.targetCount, (_) => GlobalKey());
  late final VoidCallback _interruptCallback = _interrupt;
  late final ShowcaseView _guide;
  bool _scheduled = false;
  bool _attempting = false;
  bool _attempted = false;
  bool _interrupted = false;
  bool _manual = false;

  String? get _storageKey {
    final id = widget.accountId?.trim() ?? '';
    return id.isEmpty
        ? null
        : 'guide.${widget.name}.v1.${Uri.encodeComponent(id)}';
  }

  @override
  void initState() {
    super.initState();
    _manual = widget.replay > 0;
    _guide = ShowcaseView.register(
      scope: _scope,
      skipIfTargetNotPresent: true,
      enableAutoScroll: true,
      disableMovingAnimation: true,
      disableScaleAnimation: true,
      disableBarrierInteraction: true,
      semanticEnable: true,
      globalTooltipActionConfig: const TooltipActionConfig(
        position: TooltipActionPosition.insideRight,
        mainAxisSize: MainAxisSize.min,
      ),
      globalTooltipActions: const [
        TooltipActionButton(
            type: TooltipDefaultActionType.previous, name: 'السابق'),
        TooltipActionButton(
            type: TooltipDefaultActionType.next, name: 'التالي'),
        TooltipActionButton(type: TooltipDefaultActionType.skip, name: 'تخطي'),
      ],
      onFinish: () {
        GuideCoordinator.release(_interruptCallback);
        unawaited(_record('completed'));
      },
      onDismiss: (_) {
        GuideCoordinator.release(_interruptCallback);
        if (!_interrupted) unawaited(_record('skipped'));
      },
    );
  }

  @override
  void didUpdateWidget(GuidedTour oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.replay != oldWidget.replay) {
      _attempted = false;
      _manual = true;
    }
  }

  void _interrupt() {
    if (!_guide.isShowcaseRunning) return;
    _interrupted = true;
    _guide.dismiss();
    _interrupted = false;
  }

  Future<void> _record(String status) async {
    final key = _storageKey;
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(key, status)) {
        throw StateError('تعذر حفظ حالة الشرح');
      }
    } catch (error, stack) {
      debugPrint('Unable to save guide state: $error\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ حالة الشرح: $error')),
        );
      }
    }
  }

  Future<void> _start() async {
    if (!mounted ||
        !widget.ready ||
        !GuideCoordinator.ready ||
        !(widget.canStart?.call() ?? true) ||
        _attempting ||
        _attempted ||
        _storageKey == null) {
      return;
    }
    _attempting = true;
    try {
      if (!_manual) {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getString(_storageKey!) != null) {
          _attempted = true;
          return;
        }
      }
      if (!mounted ||
          !widget.ready ||
          !GuideCoordinator.ready ||
          !(widget.canStart?.call() ?? true) ||
          ModalRoute.of(context)?.isCurrent != true ||
          DeepLinkService.hasPendingNotification ||
          context.read<AppUpdateService?>()?.isRequired == true ||
          (WidgetsBinding.instance.lifecycleState != null &&
              WidgetsBinding.instance.lifecycleState !=
                  AppLifecycleState.resumed)) {
        return;
      }
      final targets = _keys.where(_guide.isTargetRendered).toList();
      if (targets.isEmpty || !GuideCoordinator.claim(_interruptCallback)) {
        return;
      }
      _attempted = true;
      _manual = false;
      _guide.startShowCase(targets);
    } catch (error, stack) {
      GuideCoordinator.release(_interruptCallback);
      debugPrint('Unable to start guide: $error\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر عرض الشرح: $error')),
        );
      }
    } finally {
      _attempting = false;
    }
  }

  Widget _target(int index, String description, Widget child) {
    if (_storageKey == null) return child;
    final colors = Theme.of(context).colorScheme;
    return Showcase(
      key: _keys[index],
      scope: _scope,
      description: description,
      descriptionTextDirection: TextDirection.rtl,
      tooltipBackgroundColor: colors.surface,
      textColor: colors.onSurface,
      disableDefaultTargetGestures: true,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ready && !_attempted && !_scheduled) {
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduled = false;
        unawaited(_start());
      });
    }
    return widget.builder(context, _target);
  }

  @override
  void dispose() {
    _guide.unregister();
    GuideCoordinator.release(_interruptCallback);
    super.dispose();
  }
}
