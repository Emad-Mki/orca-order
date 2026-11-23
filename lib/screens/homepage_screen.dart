import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../utils/permissions.dart';
import '../services/api_service.dart';
import '../services/deep_link_service.dart';
import '../services/fcm_service.dart';
import '../providers/notification_provider.dart';
import '../widgets/notification_badge.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import '../services/app_update_service.dart';
import '../services/guide_coordinator.dart';
import 'screens.dart';

class HomePage extends StatefulWidget {
  final Map<String, dynamic> session;
  final VoidCallback onLogout;
  final Future<void>? tutorialGate;

  const HomePage({
    super.key,
    required this.session,
    required this.onLogout,
    this.tutorialGate,
  });

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int selectedIndex = 2; // الافتراضي: الرئيسية
  late AppRole userRole;
  late List<_NavConfig> _navItems;
  late final PageController _pageController;
  bool _confirmingExit = false;
  bool _routeOpen = false;
  final GlobalKey _productsGuideKey = GlobalKey();
  final GlobalKey _orderGuideKey = GlobalKey();
  final GlobalKey _moreGuideKey = GlobalKey();
  ShowcaseView? _guide;
  bool _guideStarting = false;
  bool _notificationsInitialized = false;
  bool _guideGateOpen = false;
  int _productsGuideReplay = 0;
  bool _guideInterrupted = false;
  late final VoidCallback _interruptGuideCallback = _interruptGuide;

  void _interruptGuide() {
    final guide = _guide;
    if (guide == null || !guide.isShowcaseRunning) return;
    _guideInterrupted = true;
    guide.dismiss();
    _guideInterrupted = false;
  }

  String? get _guideStorageKey {
    final id = widget.session['user_id']?.toString().trim() ?? '';
    if (userRole != AppRole.customer || id.isEmpty) return null;
    return 'guide.home.v1.${Uri.encodeComponent(id)}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final roleString = widget.session['role'] ?? 'user';
    userRole = PermissionHelper.fromString(roleString);
    if (_guideStorageKey != null) {
      _guide = ShowcaseView.register(
        scope: 'customer-home',
        skipIfTargetNotPresent: true,
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
          TooltipActionButton(
              type: TooltipDefaultActionType.skip, name: 'تخطي'),
        ],
        onFinish: () {
          GuideCoordinator.release(_interruptGuideCallback);
          unawaited(_recordGuide('completed'));
        },
        onDismiss: (_) {
          GuideCoordinator.release(_interruptGuideCallback);
          if (!_guideInterrupted) unawaited(_recordGuide('skipped'));
        },
      );
    }
    _setupNavigation();
    _pageController = PageController(initialPage: selectedIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      DeepLinkService.navigationReady = true;
      unawaited(_prepareNotificationsAndGuide());
    });
    widget.tutorialGate?.then((_) {
      _guideGateOpen = true;
      _updateGuideReadiness();
      unawaited(_tryStartGuide());
    });
  }

  Future<void> _prepareNotificationsAndGuide() async {
    try {
      await _initializeNotifications();
    } catch (error, stack) {
      debugPrint('Unable to prepare notifications: $error\n$stack');
      return;
    }
    if (!mounted) return;
    _notificationsInitialized = true;
    _updateGuideReadiness();
    await _tryStartGuide();
  }

  void _updateGuideReadiness() {
    if (!mounted) return;
    setState(() {
      GuideCoordinator.ready = _guideGateOpen && _notificationsInitialized;
    });
  }

  Future<void> _recordGuide(String status) async {
    final key = _guideStorageKey;
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(key, status)) {
        throw StateError('تعذر حفظ حالة الشرح');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ حالة الشرح: $error')),
        );
      }
    }
  }

  Future<void> _tryStartGuide({bool manual = false}) async {
    final guide = _guide;
    final key = _guideStorageKey;
    if (!mounted ||
        guide == null ||
        key == null ||
        _guideStarting ||
        guide.isShowcaseRunning ||
        !_guideGateOpen ||
        !_notificationsInitialized) {
      if (manual && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('سيكون الشرح متاحًا بعد اكتمال تهيئة التطبيق.'),
        ));
      }
      return;
    }
    _guideStarting = true;
    try {
      if (!manual) {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getString(key) != null) return;
      }
      if (!mounted ||
          selectedIndex != 2 ||
          _routeOpen ||
          ModalRoute.of(context)?.isCurrent != true ||
          DeepLinkService.hasPendingNotification ||
          context.read<AppUpdateService?>()?.isRequired == true ||
          (WidgetsBinding.instance.lifecycleState != null &&
              WidgetsBinding.instance.lifecycleState !=
                  AppLifecycleState.resumed)) {
        if (manual && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تعذر عرض الشرح الآن. أعد المحاولة لاحقًا.'),
          ));
        }
        return;
      }
      final targets = [_productsGuideKey, _orderGuideKey, _moreGuideKey]
          .where(guide.isTargetRendered)
          .toList();
      if (targets.isNotEmpty &&
          GuideCoordinator.claim(_interruptGuideCallback)) {
        guide.startShowCase(targets);
      }
    } catch (error) {
      GuideCoordinator.release(_interruptGuideCallback);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر عرض الشرح: $error')),
        );
      }
    } finally {
      _guideStarting = false;
    }
  }

  Widget _guideTarget(GlobalKey key, String description, Widget child) {
    if (_guide == null) return child;
    final colors = Theme.of(context).colorScheme;
    return Showcase(
      key: key,
      scope: 'customer-home',
      description: description,
      descriptionTextDirection: TextDirection.rtl,
      tooltipBackgroundColor: colors.surface,
      textColor: colors.onSurface,
      disableDefaultTargetGestures: true,
      child: child,
    );
  }

  Future<void> _initializeNotifications() async {
    final notificationProvider = context.read<NotificationProvider>();
    try {
      await FcmService.instance.bindUser(widget.session);
    } catch (error) {
      debugPrint('Unable to initialize user notifications: $error');
    }
    if (!mounted) return;
    await notificationProvider.load();
    await FcmService.instance.handlePendingTap();
    FcmService.instance.onForegroundMessage = () async {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      await notificationProvider.load();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('لديك إشعار جديد'),
            action: SnackBarAction(
              label: 'عرض',
              onPressed: () => navigator.push(
                MaterialPageRoute(
                  builder: (_) => const NotificationsScreen(),
                ),
              ),
            ),
          ),
        );
      }
    };
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    FcmService.instance.refreshRegistration().catchError((Object error) {
      debugPrint('Unable to refresh notification device: $error');
    });
    unawaited(FcmService.instance.handlePendingTap());
    unawaited(DeepLinkService.resumePendingNotification());
    if (mounted) context.read<NotificationProvider>().load();
  }

  @override
  void dispose() {
    GuideCoordinator.ready = false;
    DeepLinkService.navigationReady = false;
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _guide?.unregister();
    GuideCoordinator.release(_interruptGuideCallback);
    super.dispose();
  }

  void _setupNavigation() {
    final isSalesperson = userRole == AppRole.salesperson;
    _navItems = [
      _NavConfig(
        0,
        isSalesperson ? Icons.receipt_long : Icons.assignment,
        isSalesperson ? 'فواتيري' : 'الطلبات',
        (s) => isSalesperson
            ? SalesInvoicesScreen(session: s)
            : OrdersScreen(session: s, motionVisible: selectedIndex == 0),
      ),
      _NavConfig(
          1,
          Icons.inventory_2,
          'المنتجات',
          (s) => ProductsScreen(
                session: s,
                guideVisible: selectedIndex == 1,
                guideReplay: _productsGuideReplay,
              )),
      _NavConfig(2, Icons.home, 'الرئيسية',
          (s) => DashboardScreen(session: s, userRole: userRole)),
      _NavConfig(
        3,
        isSalesperson ? Icons.bar_chart : Icons.account_balance_wallet,
        isSalesperson ? 'مبيعاتي' : 'كشف حساب',
        (s) {
          if (isSalesperson) {
            return SalesInvoicesScreen(session: s);
          }
          if (userRole == AppRole.warehouse) {
            return const Scaffold(
                body: Center(child: Text('غير متاح لأمين المستودع')));
          }
          return const CustomerStatementScreen();
        },
      ),
      _NavConfig(4, Icons.more_horiz, 'المزيد', null),
    ];
  }

  void _onItemTapped(int index) {
    if (_navItems[index].label == 'المزيد') {
      _showMoreMenu();
    } else {
      setState(() => selectedIndex = index);
      _pageController.jumpToPage(index);
    }
  }

  Future<void> _handleBack() async {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    if (selectedIndex != 2) {
      _onItemTapped(2);
      return;
    }
    if (_confirmingExit) return;
    _confirmingExit = true;
    final exit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('هل تريد إغلاق التطبيق؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('متابعة الاستخدام'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إغلاق التطبيق'),
          ),
        ],
      ),
    );
    _confirmingExit = false;
    if (exit == true) await SystemNavigator.pop();
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildMoreBottomSheet(),
    );
  }

  Widget _buildMoreBottomSheet() {
    final theme = Theme.of(context);
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('المزيد من الخيارات', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 20),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: _buildMoreOptions(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMoreOptions() {
    List<Widget> options = [];

    if (userRole == AppRole.admin ||
        userRole == AppRole.manager ||
        userRole == AppRole.accountant ||
        userRole == AppRole.customer) {
      options.add(_buildMenuOption(Icons.edit_note, 'مسوداتي',
          () => _navigate(DraftsListScreen(session: widget.session))));
    }

    if (userRole == AppRole.admin) {
      options.addAll([
        _buildMenuOption(Icons.people, 'العملاء',
            () => _navigate(CustomersScreen(session: widget.session))),
        _buildMenuOption(Icons.inventory, 'المخزون',
            () => _navigate(InventoryScreen(session: widget.session))),
        _buildMenuOption(Icons.input, 'الاستلامات',
            () => _navigate(const PendingApprovalScreen())),
        _buildMenuOption(Icons.fact_check, 'الجرد',
            () => _navigate(const InventoryMovementsScreen())),
        _buildMenuOption(Icons.receipt_long, 'الفواتير',
            () => _navigate(const NewOrdersListScreen())),
        _buildMenuOption(Icons.point_of_sale, 'فواتير المبيعات',
            () => _navigate(SalesInvoicesScreen(session: widget.session))),
        _buildMenuOption(Icons.account_balance_wallet, 'الصناديق والحركات',
            () => _navigate(const CashBoxesScreen())),
        _buildMenuOption(Icons.add_card, 'سند قبض من زبون',
            () => _navigate(const CustomerReceiptScreen())),
        _buildMenuOption(Icons.assessment, 'التقارير',
            () => _navigate(ReportsScreen(session: widget.session))),
        _buildMenuOption(Icons.manage_accounts, 'إدارة المستخدمين',
            () => _navigate(UserManagementScreen(session: widget.session))),
        _buildMenuOption(Icons.history, 'سجل العمليات',
            () => _navigate(AuditLogScreen(session: widget.session))),
        _buildMenuOption(Icons.backup, 'النسخ الاحتياطي',
            () => _navigate(BackupSettingsScreen(session: widget.session))),
        _buildMenuOption(Icons.settings_applications, 'إعدادات النظام',
            () => _navigate(SystemSettingsScreen(session: widget.session))),
      ]);
    } else if (userRole == AppRole.manager) {
      options.addAll([
        _buildMenuOption(Icons.people, 'العملاء',
            () => _navigate(CustomersScreen(session: widget.session))),
        _buildMenuOption(Icons.inventory, 'المخزون',
            () => _navigate(InventoryScreen(session: widget.session))),
        _buildMenuOption(Icons.input, 'الاستلامات',
            () => _navigate(const PendingApprovalScreen())),
        _buildMenuOption(Icons.fact_check, 'الجرد',
            () => _navigate(const InventoryMovementsScreen())),
        _buildMenuOption(Icons.receipt_long, 'الفواتير',
            () => _navigate(const NewOrdersListScreen())),
        _buildMenuOption(Icons.assessment, 'التقارير',
            () => _navigate(ReportsScreen(session: widget.session))),
        _buildMenuOption(Icons.point_of_sale, 'فواتير المبيعات',
            () => _navigate(SalesInvoicesScreen(session: widget.session))),
        _buildMenuOption(Icons.payments, 'الدفعات',
            () => _navigate(PaymentsScreen(session: widget.session))),
        _buildMenuOption(Icons.account_balance_wallet, 'الصناديق والحركات',
            () => _navigate(const CashBoxesScreen())),
        _buildMenuOption(Icons.add_card, 'سند قبض من زبون',
            () => _navigate(const CustomerReceiptScreen())),
      ]);
    } else if (userRole == AppRole.accountant) {
      options.addAll([
        _buildMenuOption(Icons.people, 'العملاء',
            () => _navigate(CustomersScreen(session: widget.session))),
        _buildMenuOption(Icons.receipt_long, 'الفواتير',
            () => _navigate(const NewOrdersListScreen())),
        _buildMenuOption(Icons.payments, 'الدفعات',
            () => _navigate(PaymentsScreen(session: widget.session))),
        _buildMenuOption(Icons.point_of_sale, 'فواتير المبيعات',
            () => _navigate(SalesInvoicesScreen(session: widget.session))),
        _buildMenuOption(Icons.account_balance_wallet, 'الصناديق والحركات',
            () => _navigate(const CashBoxesScreen())),
        _buildMenuOption(Icons.add_card, 'سند قبض من زبون',
            () => _navigate(const CustomerReceiptScreen())),
        _buildMenuOption(Icons.assessment, 'التقارير المسموحة',
            () => _navigate(ReportsScreen(session: widget.session))),
        _buildMenuOption(Icons.manage_accounts, 'إدارة الحسابات',
            () => _navigate(UserManagementScreen(session: widget.session))),
      ]);
    } else if (userRole == AppRole.warehouse) {
      options.addAll([
        _buildMenuOption(Icons.inventory, 'المخزون',
            () => _navigate(InventoryScreen(session: widget.session))),
        _buildMenuOption(Icons.swap_horiz, 'الحركات',
            () => _navigate(const InventoryMovementsScreen())),
        _buildMenuOption(Icons.input, 'الاستلامات',
            () => _navigate(const PendingApprovalScreen())),
        _buildMenuOption(Icons.fact_check, 'الجرد',
            () => _navigate(const InventoryMovementsScreen())),
        _buildMenuOption(Icons.local_shipping, 'الشحن',
            () => _navigate(const ShippingScreen())),
      ]);
    } else if (userRole == AppRole.customer) {
      options.addAll([
        _buildMenuOption(Icons.person, 'بيانات الحساب',
            () => _navigate(ProfileScreen(session: widget.session))),
        _buildMenuOption(Icons.location_on, 'العناوين', () => {}),
        _buildMenuOption(Icons.contact_support, 'التواصل', () => {}),
        _buildMenuOption(Icons.archive, 'الإشعارات المؤرشفة',
            () => _navigate(const NotificationsScreen())),
        _buildMenuOption(Icons.info, 'حول التطبيق', () => {}),
        _buildMenuOption(Icons.help, 'الدعم', () => {}),
      ]);
    } else if (userRole == AppRole.salesperson) {
      options.addAll([
        _buildMenuOption(Icons.add_shopping_cart, 'فاتورة مبيع جديدة',
            () => _navigate(const SalesInvoiceScreen())),
        _buildMenuOption(Icons.receipt_long, 'فواتيري ومقبوضاتي',
            () => _navigate(SalesInvoicesScreen(session: widget.session))),
      ]);
    }

    options.add(const Divider());
    options.add(_buildMenuOption(Icons.logout, 'تسجيل الخروج', _confirmLogout,
        color: Colors.red));

    return options;
  }

  Widget _buildMenuOption(IconData icon, String title, VoidCallback onTap,
      {Color? color}) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(color: color)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: onTap,
      ),
    );
  }

  void _navigate(Widget screen) {
    Navigator.pop(context);
    unawaited(_pushScreen(screen));
  }

  Future<void> _pushScreen(Widget screen) async {
    if (_routeOpen) return;
    _routeOpen = true;
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => screen),
      );
    } finally {
      _routeOpen = false;
    }
  }

  Future<void> _openSettings() async {
    if (_routeOpen) return;
    _routeOpen = true;
    Object? replay;
    try {
      replay = await Navigator.push<Object?>(
        context,
        MaterialPageRoute(
          builder: (_) => SettingsScreen(session: widget.session),
        ),
      );
    } finally {
      _routeOpen = false;
    }
    if (replay == true && mounted) {
      await _tryStartGuide(manual: true);
    } else if (replay == 'products' && mounted) {
      setState(() {
        _productsGuideReplay++;
        selectedIndex = 1;
      });
      _pageController.jumpToPage(1);
    }
  }

  void _confirmLogout() {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text(
            'هل أنت متأكد من رغبتك في الخروج؟ سيتم مسح البيانات المحلية المؤقتة.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final notificationProvider =
                    context.read<NotificationProvider>();
                final messenger = ScaffoldMessenger.of(context);
                navigator.pop();
                String? logoutError;
                String? deviceId;
                try {
                  deviceId = await FcmService.instance.getDeviceId();
                  await FcmService.instance.unbindUser();
                } catch (error) {
                  FcmService.instance.clearUserSession();
                  logoutError = 'تعذر تعطيل إشعارات هذا الجهاز: $error';
                }
                notificationProvider.reset();
                try {
                  await ApiService().auth.logout(deviceId: deviceId);
                } catch (error) {
                  logoutError =
                      'تم إنهاء الجلسة محلياً، وتعذر تأكيد الإبطال على الخادم: $error';
                }
                if (mounted && logoutError != null) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(logoutError)),
                  );
                }
                if (mounted) {
                  navigator.popUntil((route) => route.isFirst);
                  widget.onLogout();
                }
              },
              child: const Text('خروج')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<NotificationProvider>().unreadCount;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_handleBack());
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          leading: IconButton(
            onPressed: _openSettings,
            tooltip: 'الإعدادات',
            icon: const Icon(Icons.settings),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/logo.png',
                  height: 30,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.shopping_basket)),
              const SizedBox(width: 8),
              const Text('أوركا أوردر',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            NotificationBadge(
              count: unreadCount,
              onTap: () => _pushScreen(const NotificationsScreen()),
            ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _navItems.length - 1,
            onPageChanged: (index) => setState(() => selectedIndex = index),
            itemBuilder: (context, index) => _KeepAlivePage(
              child: _navItems[index].builder!(widget.session),
            ),
          ),
        ),
        floatingActionButton: selectedIndex == 2
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (const {AppRole.admin, AppRole.manager, AppRole.accountant}
                      .contains(userRole)) ...[
                    FloatingActionButton.extended(
                      heroTag: 'new-sales-invoice',
                      onPressed: () => _pushScreen(const SalesInvoiceScreen()),
                      icon: const Icon(Icons.point_of_sale),
                      label: const Text('فاتورة جديدة'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _guideTarget(
                    _orderGuideKey,
                    'ابدأ طلبًا جديدًا، ثم راجع الكميات قبل الإرسال.',
                    FloatingActionButton.extended(
                      heroTag: 'new-order',
                      onPressed: () => _pushScreen(
                        userRole == AppRole.salesperson
                            ? const SalesInvoiceScreen()
                            : NewOrderScreen(session: widget.session),
                      ),
                      icon: const Icon(Icons.add_shopping_cart),
                      label: Text(
                        userRole == AppRole.salesperson
                            ? 'فاتورة نقدية'
                            : 'إضافة طلب',
                      ),
                    ),
                  ),
                ],
              )
            : null,
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    final theme = Theme.of(context);
    return Container(
      height: 75 + MediaQuery.of(context).padding.bottom,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.85),
        border: Border(
            top: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.1))),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (i) {
              final item = _navItems[i];
              final isSelected = selectedIndex == i;
              if (item.label == 'الرئيسية') return _buildCenterFab(i, item);
              final child = _buildNavItem(i, item, isSelected);
              if (item.label == 'المنتجات') {
                return _guideTarget(
                    _productsGuideKey,
                    'تصفح المنتجات وابحث بالاسم أو الرمز، ثم افتح تفاصيل المنتج.',
                    child);
              }
              if (item.label == 'المزيد') {
                return _guideTarget(_moreGuideKey,
                    'ستجد هنا المسودات والخيارات المتاحة لحسابك.', child);
              }
              return child;
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, _NavConfig item, bool isSelected) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant),
          Text(item.label,
              style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildCenterFab(int index, _NavConfig item) {
    final theme = Theme.of(context);
    final isSelected = selectedIndex == index;
    return InkWell(
      onTap: () => _onItemTapped(index),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.primary.withValues(alpha: 0.8),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4))
          ],
        ),
        child: Icon(item.icon, color: Colors.white),
      ),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});
  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _NavConfig {
  final int index;
  final IconData icon;
  final String label;
  final Widget Function(Map<String, dynamic>)? builder;
  _NavConfig(this.index, this.icon, this.label, this.builder);
}
