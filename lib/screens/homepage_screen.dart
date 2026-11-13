import 'package:flutter/material.dart';
import 'dart:ui';
import '../utils/permissions.dart';
import '../services/api_service.dart';
import '../services/fcm_service.dart';
import '../providers/notification_provider.dart';
import '../widgets/notification_badge.dart';
import 'package:provider/provider.dart';
import 'screens.dart';

class HomePage extends StatefulWidget {
  final Map<String, dynamic> session;
  final VoidCallback onLogout;

  const HomePage({super.key, required this.session, required this.onLogout});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int selectedIndex = 2; // الافتراضي: الرئيسية
  late AppRole userRole;
  late List<_NavConfig> _navItems;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final roleString = widget.session['role'] ?? 'user';
    userRole = PermissionHelper.fromString(roleString);
    _setupNavigation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNotifications();
    });
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
    if (mounted) context.read<NotificationProvider>().load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
            : OrdersScreen(session: s),
      ),
      _NavConfig(
          1, Icons.inventory_2, 'المنتجات', (s) => ProductsScreen(session: s)),
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
    }
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
        _buildMenuOption(Icons.assessment, 'التقارير',
            () => _navigate(ReportsScreen(session: widget.session))),
        _buildMenuOption(Icons.manage_accounts, 'إدارة المستخدمين',
            () => _navigate(UserManagementScreen(session: widget.session))),
        _buildMenuOption(Icons.swap_horiz, 'تخصيص مخزون للمندوب',
            () => _navigate(const SalesStockTransferScreen())),
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
        _buildMenuOption(Icons.swap_horiz, 'تخصيص مخزون للمندوب',
            () => _navigate(const SalesStockTransferScreen())),
      ]);
    } else if (userRole == AppRole.accountant) {
      options.addAll([
        _buildMenuOption(Icons.people, 'العملاء',
            () => _navigate(CustomersScreen(session: widget.session))),
        _buildMenuOption(Icons.receipt_long, 'الفواتير',
            () => _navigate(const NewOrdersListScreen())),
        _buildMenuOption(
            Icons.payments, 'الدفعات', () => _navigate(const PaymentsScreen())),
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
        _buildMenuOption(Icons.swap_horiz, 'تخصيص مخزون للمندوب',
            () => _navigate(const SalesStockTransferScreen())),
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
        _buildMenuOption(Icons.add_shopping_cart, 'فاتورة نقدية جديدة',
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
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: onTap,
    );
  }

  void _navigate(Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
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
                Navigator.pop(context);
                final notificationProvider =
                    context.read<NotificationProvider>();
                final messenger = ScaffoldMessenger.of(context);
                String? logoutError;
                final deviceId = await FcmService.instance.getDeviceId();
                try {
                  await FcmService.instance.unbindUser();
                } catch (error) {
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
                widget.onLogout();
              },
              child: const Text('خروج')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<NotificationProvider>().unreadCount;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => SettingsScreen(session: widget.session))),
          icon: const Icon(Icons.settings),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/app_icon.png',
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
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationsScreen(),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: _navItems[selectedIndex].builder!(widget.session),
      ),
      floatingActionButton: selectedIndex == 2
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => userRole == AppRole.salesperson
                      ? const SalesInvoiceScreen()
                      : NewOrderScreen(session: widget.session),
                ),
              ),
              icon: const Icon(Icons.add_shopping_cart),
              label: Text(
                userRole == AppRole.salesperson ? 'فاتورة نقدية' : 'إضافة طلب',
              ),
            )
          : null,
      bottomNavigationBar: _buildBottomNav(),
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
              return _buildNavItem(i, item, isSelected);
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

class _NavConfig {
  final int index;
  final IconData icon;
  final String label;
  final Widget Function(Map<String, dynamic>)? builder;
  _NavConfig(this.index, this.icon, this.label, this.builder);
}
