import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../repositories/local_repository.dart';
import '../settings/setting_definitions.dart';
import '../services/api_service.dart';
import '../services/fcm_service.dart';
import '../utils/permissions.dart';
import '../utils/guarded_navigation.dart';
import '../widgets/app_update_settings_tile.dart';
import '../widgets/guided_tour.dart';
import '../services/guide_coordinator.dart';
import 'profile_screen.dart';
import 'sales_settings_screen.dart';
import 'offers_admin_screen.dart';

/// شاشة الإعدادات
class SettingsScreen extends StatefulWidget {
  final Map<String, dynamic> session;

  const SettingsScreen({super.key, required this.session});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _csvIdCtrl = TextEditingController();
  bool _loading = false;
  bool _savingTheme = false;
  bool _syncingNotifications = false;
  bool _clearingCache = false;
  bool _allowPop = false;
  Map<String, dynamic>? _imageIndexStatus;
  Timer? _imageIndexPollTimer;
  bool _imageIndexStatusRequestActive = false;
  bool _imageIndexScheduledUpdate = false;
  late Future<FcmDiagnostics> _notificationDiagnostics;
  Future<DateTime?>? _lastProductSync;
  LocalRepository? _localRepository;
  int _guideReplay = 0;
  final ScrollController _settingsScroll = ScrollController();
  bool get _guideControlsBusy =>
      _loading || _savingTheme || _syncingNotifications || _clearingCache;

  void _leaveForGuide(Object result) {
    if (_csvIdCtrl.text.trim().isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('احفظ معرف المزامنة أو امسحه قبل مغادرة الإعدادات.'),
      ));
      return;
    }
    popAfterGuard(context,
        allowPop: () => setState(() => _allowPop = true), result: result);
  }

  Future<void> _replayPageGuide(
      String accountId, String name, String message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs
          .remove('guide.$name.v1.${Uri.encodeComponent(accountId)}')) {
        throw StateError('تعذر إعادة تهيئة الشرح');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
        ));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إعادة عرض الشرح: $error')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _notificationDiagnostics = FcmService.instance.getDiagnostics();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _canManageImageIndex) {
        _refreshImageIndexStatus();
      }
    });
  }

  @override
  void dispose() {
    _imageIndexPollTimer?.cancel();
    _settingsScroll.dispose();
    _csvIdCtrl.dispose();
    super.dispose();
  }

  bool get _canManageImageIndex => PermissionHelper.hasPermission(
        PermissionHelper.fromString(
          (ApiService().currentUser ?? widget.session)['role']?.toString() ??
              '',
        ),
        AppPermission.manageSystemSettings,
      );

  bool get _imageIndexIsActive => const {
        'pending',
        'running',
        'continuing',
        'publishing',
      }.contains(_imageIndexStatus?['status']);

  void _updateImageIndexPolling() {
    _imageIndexPollTimer?.cancel();
    if (_imageIndexIsActive) {
      _imageIndexPollTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _refreshImageIndexStatus(),
      );
    }
  }

  Future<void> _refreshImageIndexStatus() async {
    if (_imageIndexStatusRequestActive || !_canManageImageIndex) return;
    _imageIndexStatusRequestActive = true;
    try {
      final response = await ApiService().post(
        {'action': 'image_index_status'},
      );
      if (!mounted) return;
      setState(() {
        _imageIndexStatus = response;
        _imageIndexScheduledUpdate = response['scheduled_update'] == true;
      });
      _updateImageIndexPolling();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر قراءة حالة فهرس الصور: $error')),
        );
      }
    } finally {
      _imageIndexStatusRequestActive = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = context.read<LocalRepository?>();
    if (!identical(repository, _localRepository)) {
      _localRepository = repository;
      _lastProductSync = repository?.getLastSync('products');
    }
  }

  Future<void> _clearProductCache() async {
    final repository = _localRepository;
    if (repository == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مسح ذاكرة المنتجات والصور؟'),
        content: const Text(
          'ستُحذف النسخ المحلية للمنتجات والصور وقد يتطلب عرضها اتصالاً لاحقاً. '
          'لن تُحذف المسودات أو العمليات غير المتزامنة. '
          'قد تبقى المنتجات المفتوحة في الذاكرة حتى إعادة تحميل التطبيق.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('مسح الذاكرة'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _clearingCache = true);
    try {
      await repository.clearProductCache();
      await ApiService().auth.clearLocalCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم مسح ذاكرة المنتجات والصور المحلية')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر مسح الذاكرة بالكامل: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _clearingCache = false);
    }
  }

  Future<void> _updateConfig() async {
    setState(() => _loading = true);
    try {
      await ApiService().post({
        'action': 'updateConfig',
        SettingDefinitions.syncFileId.key: _csvIdCtrl.text.trim(),
      });
      if (mounted) {
        _csvIdCtrl.clear();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم حفظ الإعدادات')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر حفظ الإعدادات: $error')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _syncNow() async {
    setState(() => _loading = true);
    try {
      final response = await ApiService().post({
        'action': 'syncFromDrive',
        SettingDefinitions.syncFileId.key: _csvIdCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'تمت المزامنة')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذرت المزامنة: $error')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _rebuildImages({bool full = false}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text(full ? 'إعادة بناء فهرس الصور بالكامل؟' : 'تحديث فهرس الصور؟'),
        content: const Text(
          'سيبقى الفهرس الحالي متاحاً أثناء التحديث. '
          'التحديث الاعتيادي يعالج تغييرات Drive فقط؛ إعادة البناء الكاملة '
          'تفحص ملفات المجلد كلها.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(full ? 'إعادة البناء' : 'بدء التحديث'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final response = await ApiService().post(
        full
            ? {'action': 'image_index_restart', 'confirmed': true}
            : {'action': 'rebuildImageIndex'},
      );
      if (mounted) {
        setState(() {
          _imageIndexStatus = response;
          _imageIndexScheduledUpdate = response['scheduled_update'] == true;
        });
        _updateImageIndexPolling();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'بدأت مهمة فهرس الصور'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديث فهرس الصور: $error')),
        );
      }
    }
  }

  Future<void> _toggleImageIndexSchedule() async {
    final enabled = !_imageIndexScheduledUpdate;
    try {
      final response = await ApiService().post({
        'action': 'image_index_schedule',
        'enabled': enabled,
      });
      if (!mounted) return;
      setState(() =>
          _imageIndexScheduledUpdate = response['scheduled_update'] == true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enabled
              ? 'تم تفعيل التحديث الدوري كل 6 ساعات'
              : 'تم إيقاف التحديث الدوري'),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تغيير التحديث الدوري: $error')),
        );
      }
    }
  }

  Future<void> _resumeImageIndexJob() async {
    try {
      final response = await ApiService().post(
        {'action': 'image_index_resume'},
      );
      if (!mounted) return;
      setState(() => _imageIndexStatus = response);
      _updateImageIndexPolling();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر استئناف فهرس الصور: $error')),
        );
      }
    }
  }

  Future<void> _cancelImageIndexJob() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء مهمة فهرس الصور؟'),
        content: const Text('سيبقى الفهرس النشط كما هو.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('متابعة المهمة'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إلغاء المهمة'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final response = await ApiService().post(
        {'action': 'image_index_cancel'},
      );
      if (!mounted) return;
      setState(() => _imageIndexStatus = response);
      _updateImageIndexPolling();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إلغاء مهمة فهرس الصور: $error')),
        );
      }
    }
  }

  Future<void> _changeThemeMode(ThemeMode mode) async {
    final appState = context.findAncestorStateOfType<OrcaAppState>();
    if (appState == null) return;
    setState(() => _savingTheme = true);
    try {
      await appState.setThemeMode(mode);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ تفضيل المظهر: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingTheme = false);
    }
  }

  Future<void> _resetTheme() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('استعادة المظهر الافتراضي؟'),
        content:
            const Text('سيعود مظهر هذا الجهاز إلى اتباع إعداد النظام فقط.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('استعادة'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _changeThemeMode(ThemeMode.system);
  }

  Future<void> _back() async {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    if (_loading || _savingTheme || _syncingNotifications || _clearingCache) {
      return;
    }
    if (_csvIdCtrl.text.trim().isEmpty) {
      popAfterGuard(context, allowPop: () => setState(() => _allowPop = true));
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديلات غير محفوظة'),
        content: const Text('لم يُحفظ معرف ملف المزامنة بعد.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('متابعة التحرير'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تجاهل التعديلات'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      popAfterGuard(context, allowPop: () => setState(() => _allowPop = true));
    }
  }

  Future<void> _syncNotifications() async {
    setState(() => _syncingNotifications = true);
    String? errorMessage;
    try {
      await FcmService.instance.syncRegistration();
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      if (mounted) {
        setState(() {
          _syncingNotifications = false;
          _notificationDiagnostics = FcmService.instance.getDiagnostics();
        });
      }
    }
    if (mounted && errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  void _refreshNotificationDiagnostics() {
    setState(() {
      _notificationDiagnostics = FcmService.instance.getDiagnostics();
    });
  }

  Widget _buildNotificationDiagnostics() => Card(
        child: FutureBuilder<FcmDiagnostics>(
          future: _notificationDiagnostics,
          builder: (context, snapshot) {
            final diagnostics = snapshot.data;
            final lastSync = diagnostics?.lastSyncAt;
            return Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('تشخيص الإشعارات'),
                  subtitle: snapshot.connectionState == ConnectionState.waiting
                      ? const Text('جارٍ قراءة حالة الجهاز')
                      : Text(
                          diagnostics == null
                              ? 'تعذر قراءة الحالة'
                              : !diagnostics.supported
                                  ? 'الإشعارات متاحة على Android وiOS فقط'
                                  : 'Firebase: ${diagnostics.firebaseReady ? 'جاهز' : 'غير مهيأ'}'
                                      ' • الإذن: ${diagnostics.permissionLabel}'
                                      ' • تسجيل الجهاز: ${diagnostics.registered ? 'ناجح' : 'غير مسجل'}'
                                      '${diagnostics.systemNotificationsEnabled == false ? '\nإشعارات التطبيق معطلة في Android' : ''}'
                                      '${lastSync == null ? '' : '\nآخر مزامنة: ${lastSync.toLocal()}'}'
                                      '${diagnostics.lastResult == null ? '' : '\nآخر نتيجة: ${diagnostics.lastResult}'}'
                                      '${diagnostics.channelWarnings.isEmpty ? '' : '\nالقنوات: ${diagnostics.channelWarnings.join('، ')}'}',
                        ),
                  isThreeLine: true,
                ),
                Wrap(
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: diagnostics?.supported == true
                          ? () async {
                              await FcmService.instance
                                  .openNotificationSettings();
                              if (mounted) _refreshNotificationDiagnostics();
                            }
                          : null,
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('إعدادات إشعارات النظام'),
                    ),
                    TextButton.icon(
                      onPressed: _syncingNotifications ||
                              diagnostics?.supported != true
                          ? null
                          : _syncNotifications,
                      icon: _syncingNotifications
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: const Text('إعادة مزامنة الجهاز'),
                    ),
                    IconButton(
                      tooltip: 'تحديث حالة الإشعارات',
                      onPressed: _refreshNotificationDiagnostics,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    final session = ApiService().currentUser ?? widget.session;
    final userName = (session['full_name'] ??
            session['name'] ??
            session['username'] ??
            'مستخدم')
        .toString();
    final role = PermissionHelper.fromString(
      session['role']?.toString() ?? 'user',
    );
    final canManageSystem = role == AppRole.admin;
    final canManageSalesSettings =
        role == AppRole.admin || role == AppRole.accountant;
    final canSyncData =
        PermissionHelper.hasPermission(role, AppPermission.viewSettings);

    final guideAccountId =
        role == AppRole.customer ? session['user_id']?.toString() : null;
    return GuidedTour(
      accountId: guideAccountId,
      name: 'settings',
      targetCount: 3,
      replay: _guideReplay,
      ready: GuideCoordinator.ready,
      canStart: () =>
          !_loading &&
          !_savingTheme &&
          !_syncingNotifications &&
          !_clearingCache &&
          _csvIdCtrl.text.trim().isEmpty &&
          MediaQuery.viewInsetsOf(context).bottom == 0,
      builder: (context, target) => PopScope(
        canPop: _allowPop,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _back();
        },
        child: Scaffold(
          appBar: AppBar(title: const Text('الإعدادات')),
          body: SingleChildScrollView(
            controller: _settingsScroll,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                target(0, 'تحقق من تحديث التطبيق وتفاصيل الإصدار من هنا.',
                    const AppUpdateSettingsTile()),
                if (_localRepository != null)
                  Card(
                    child: Column(
                      children: [
                        FutureBuilder<DateTime?>(
                          future: _lastProductSync,
                          builder: (context, snapshot) => ListTile(
                            leading: const Icon(Icons.sync),
                            title: const Text('آخر مزامنة ناجحة للمنتجات'),
                            subtitle: Text(snapshot.hasError
                                ? 'تعذر قراءة حالة المزامنة'
                                : snapshot.connectionState ==
                                        ConnectionState.waiting
                                    ? 'جارٍ قراءة حالة المزامنة'
                                    : snapshot.data == null
                                        ? 'لا توجد مزامنة مسجلة'
                                        : snapshot.data!.toLocal().toString()),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _clearingCache ? null : _clearProductCache,
                          icon: const Icon(Icons.cleaning_services_outlined),
                          label: const Text('مسح ذاكرة المنتجات والصور'),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                          userName.isEmpty ? 'م' : userName.substring(0, 1)),
                    ),
                    title: Text(userName),
                    subtitle: Text(PermissionHelper.getRoleNameAr(role)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('تفضيلات الجهاز',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (role == AppRole.customer &&
                    (session['user_id']?.toString().trim().isNotEmpty ?? false))
                  Column(children: [
                    ListTile(
                      leading: const Icon(Icons.help_outline),
                      title: const Text('إعادة عرض الشرح'),
                      subtitle: const Text('شرح الصفحة الرئيسية'),
                      onTap: _guideControlsBusy
                          ? null
                          : () => _leaveForGuide(true),
                    ),
                    ListTile(
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: const Text('إعادة شرح المنتجات'),
                      onTap: _guideControlsBusy
                          ? null
                          : () => _leaveForGuide('products'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.fact_check_outlined),
                      title: const Text('إعادة شرح مراجعة الطلب'),
                      onTap: _guideControlsBusy
                          ? null
                          : () => _replayPageGuide(guideAccountId!, 'review',
                              'افتح مراجعة الطلب لعرض الشرح مجددًا.'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.settings_outlined),
                      title: const Text('إعادة شرح الإعدادات'),
                      onTap: _guideControlsBusy
                          ? null
                          : () {
                              if (_csvIdCtrl.text.trim().isNotEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'احفظ معرف المزامنة أو امسحه قبل عرض الشرح.')),
                                );
                                return;
                              }
                              FocusManager.instance.primaryFocus?.unfocus();
                              _settingsScroll.jumpTo(0);
                              setState(() => _guideReplay++);
                            },
                    ),
                  ]),
                if (const {
                      AppRole.admin,
                      AppRole.manager,
                      AppRole.accountant,
                      AppRole.salesperson,
                    }.contains(role) &&
                    (session['user_id']?.toString().trim().isNotEmpty ?? false))
                  ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: const Text('إعادة شرح الفاتورة'),
                    onTap: _guideControlsBusy
                        ? null
                        : () => _replayPageGuide(
                              session['user_id'].toString(),
                              'invoice',
                              'افتح فاتورة جديدة لعرض الشرح مجددًا.',
                            ),
                  ),
                target(1, 'راجع حالة الإشعارات وأعد مزامنة الجهاز عند الحاجة.',
                    _buildNotificationDiagnostics()),
                target(
                    2,
                    'اختر المظهر الفاتح أو الداكن أو إعداد الجهاز.',
                    DropdownButtonFormField<ThemeMode>(
                      key: ValueKey(
                        context
                            .findAncestorStateOfType<OrcaAppState>()
                            ?.themeMode,
                      ),
                      initialValue: context
                              .findAncestorStateOfType<OrcaAppState>()
                              ?.themeMode ??
                          ThemeMode.system,
                      decoration:
                          const InputDecoration(labelText: 'مظهر التطبيق'),
                      items: const [
                        DropdownMenuItem(
                          value: ThemeMode.system,
                          child: Text('اتباع إعداد الجهاز'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text('فاتح'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text('داكن'),
                        ),
                      ],
                      onChanged: _savingTheme || _loading
                          ? null
                          : (mode) {
                              if (mode != null) _changeThemeMode(mode);
                            },
                    )),
                if (_savingTheme) const LinearProgressIndicator(),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: _savingTheme || _loading ? null : _resetTheme,
                    child: const Text('استعادة مظهر الجهاز الافتراضي'),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('الملف الشخصي'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(session: session),
                    ),
                  ),
                ),
                if (canManageSalesSettings)
                  ListTile(
                    leading: const Icon(Icons.currency_exchange),
                    title: const Text('إعدادات البيع والعملات'),
                    subtitle: const Text('عملة الفاتورة وأسعار الصرف والدقة'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SalesSettingsScreen(),
                      ),
                    ),
                  ),
                if (const {
                  AppRole.admin,
                  AppRole.manager,
                  AppRole.accountant,
                }.contains(role))
                  ListTile(
                    leading: const Icon(Icons.local_offer_outlined),
                    title: const Text('إدارة العروض'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OffersAdminScreen(session: session),
                      ),
                    ),
                  ),
                if (canManageSystem || canSyncData) ...[
                  const Divider(height: 32),
                  Text(canManageSystem ? 'إعدادات النظام' : 'مزامنة البيانات',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (canManageSystem) ...[
                    TextField(
                      controller: _csvIdCtrl,
                      enabled: !_loading,
                      decoration: const InputDecoration(
                        labelText: 'معرف ملف CSV من Google Drive',
                        border: OutlineInputBorder(),
                        helperText: 'اتركه فارغاً للاحتفاظ بالمعرف الحالي',
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (canManageSystem)
                        FilledButton.icon(
                          onPressed: _loading ? null : _updateConfig,
                          icon: const Icon(Icons.save),
                          label: const Text('حفظ الإعدادات'),
                        ),
                      if (canSyncData)
                        FilledButton.tonalIcon(
                          onPressed: _loading ? null : _syncNow,
                          icon: const Icon(Icons.sync),
                          label: const Text('مزامنة البيانات'),
                        ),
                      if (canManageSystem)
                        OutlinedButton.icon(
                          onPressed: _loading ? null : () => _rebuildImages(),
                          icon: const Icon(Icons.image_search),
                          label: const Text('تحديث الصور الجديدة والمتغيرة'),
                        ),
                      if (canManageSystem)
                        OutlinedButton.icon(
                          onPressed: _loading
                              ? null
                              : () => _rebuildImages(full: true),
                          icon: const Icon(Icons.find_in_page_outlined),
                          label: const Text('إعادة بناء كاملة'),
                        ),
                      if (canManageSystem)
                        TextButton.icon(
                          onPressed:
                              _loading ? null : _toggleImageIndexSchedule,
                          icon: Icon(_imageIndexScheduledUpdate
                              ? Icons.schedule
                              : Icons.schedule_outlined),
                          label: Text(_imageIndexScheduledUpdate
                              ? 'إيقاف التحديث الدوري'
                              : 'تفعيل التحديث الدوري كل 6 ساعات'),
                        ),
                    ],
                  ),
                  if (canManageSystem && _imageIndexStatus != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'حالة فهرس الصور: '
                              '${_imageIndexStatus!['message'] ?? _imageIndexStatus!['status'] ?? 'غير معروفة'}',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            if (_imageIndexStatus!['jobId'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: SelectableText(
                                  'رقم المهمة: ${_imageIndexStatus!['jobId']}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            if (_imageIndexStatus!['status'] != 'idle') ...[
                              const SizedBox(height: 6),
                              Text(
                                'تم فحص ${_imageIndexStatus!['files_scanned'] ?? 0} · '
                                'أُضيف ${_imageIndexStatus!['files_added'] ?? 0} · '
                                'عُدّل ${_imageIndexStatus!['files_updated'] ?? 0} · '
                                'غير متاح ${_imageIndexStatus!['files_unavailable'] ?? 0} · '
                                'تم التجاوز ${_imageIndexStatus!['files_skipped'] ?? 0} · '
                                'الأخطاء ${_imageIndexStatus!['error_count'] ?? 0} · '
                                'المدة ${(((_imageIndexStatus!['duration_ms'] ?? 0) as num) / 1000).toStringAsFixed(1)} ث',
                                softWrap: true,
                              ),
                              if (_imageIndexStatus!['timings'] is Map)
                                Text(
                                  'Drive ${(_imageIndexStatus!['timings'] as Map)['drive_fetch_ms'] ?? 0} ms · '
                                  'قراءة الفهرس ${(_imageIndexStatus!['timings'] as Map)['index_read_ms'] ?? 0} ms · '
                                  'المطابقة ${(_imageIndexStatus!['timings'] as Map)['match_ms'] ?? 0} ms · '
                                  'الكتابة ${(_imageIndexStatus!['timings'] as Map)['write_ms'] ?? 0} ms · '
                                  'انتظار المشغّل ${(_imageIndexStatus!['timings'] as Map)['trigger_wait_ms'] ?? 0} ms',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              if (_imageIndexStatus!['last_progress_at'] !=
                                  null)
                                Text(
                                  'آخر تقدم: ${_imageIndexStatus!['last_progress_at']}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              if (_imageIndexStatus!['last_error'] != null)
                                Text(
                                  'آخر خطأ: ${_imageIndexStatus!['last_error']}',
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error),
                                ),
                              if (_imageIndexStatus!['errors'] is List &&
                                  (_imageIndexStatus!['errors'] as List)
                                      .isNotEmpty)
                                ExpansionTile(
                                  tilePadding: EdgeInsets.zero,
                                  title: const Text('تفاصيل الأخطاء'),
                                  children: [
                                    for (final error
                                        in _imageIndexStatus!['errors'] as List)
                                      ListTile(
                                        dense: true,
                                        title: Text(
                                          error is Map
                                              ? '${error['message'] ?? 'خطأ'}'
                                              : error.toString(),
                                        ),
                                        subtitle:
                                            error is Map && error['at'] != null
                                                ? Text('${error['at']}')
                                                : null,
                                      ),
                                  ],
                                ),
                              if (_imageIndexIsActive)
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: TextButton.icon(
                                    onPressed: _cancelImageIndexJob,
                                    icon: const Icon(Icons.cancel_outlined),
                                    label: const Text('إلغاء المهمة'),
                                  ),
                                )
                              else if (_imageIndexStatus!['status'] == 'failed')
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: TextButton.icon(
                                    onPressed: _resumeImageIndexJob,
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text('استئناف المهمة'),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Text(
                      'تعمل المهمة بصلاحيات حساب Google الذي أنشأ المشغّل. '
                      'قد يُطلب منك اعتماد صلاحيات Drive وSheets والمشغّلات عند البدء.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (_loading) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
