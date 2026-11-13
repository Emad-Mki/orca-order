import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/notification_provider.dart';
import 'repositories/repositories.dart';
import 'screens/screens.dart';
import 'providers/providers.dart';
import 'models/models.dart';
import 'theme/theme.dart';
import 'services/api_service.dart';
import 'services/database_service.dart';
import 'services/deep_link_service.dart';
import 'services/fcm_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة خدمة API والجلسة
  await ApiService().init();
  try {
    await Firebase.initializeApp();
    await FcmService.instance.initialize();
  } catch (error) {
    debugPrint('Firebase notifications are not configured: $error');
  }

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final preferences = await SharedPreferences.getInstance();
  final savedMode = preferences.getString('orca_theme_mode');
  final initialThemeMode = savedMode == 'dark'
      ? ThemeMode.dark
      : savedMode == 'light'
          ? ThemeMode.light
          : savedMode == 'system'
              ? ThemeMode.system
              : preferences.containsKey('orca_dark_mode')
                  ? (preferences.getBool('orca_dark_mode')!
                      ? ThemeMode.dark
                      : ThemeMode.light)
                  : ThemeMode.system;
  runApp(OrcaApp(initialThemeMode: initialThemeMode));
}

/// تطبيق Orca Order الرئيسي
class OrcaApp extends StatefulWidget {
  final ThemeMode initialThemeMode;

  const OrcaApp({
    super.key,
    this.initialThemeMode = ThemeMode.system,
  });

  @override
  State<OrcaApp> createState() => OrcaAppState();
}

class OrcaAppState extends State<OrcaApp> {
  Map<String, dynamic>? _session;
  bool _isLoading = true;
  late ThemeMode _themeMode;
  late final AppDatabase _database;

  // Repositories (will be injected into providers)
  late OrderRepository _orderRepository;
  late ProductRepository _productRepository;
  late CustomerRepository _customerRepository;
  late AuthRepository _authRepository;

  ThemeMode get themeMode => _themeMode;

  Future<void> setThemeMode(ThemeMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      'orca_theme_mode',
      switch (mode) {
        ThemeMode.system => 'system',
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
      },
    );
    if (!saved) throw StateError('تعذر حفظ تفضيل المظهر');
    if (!mounted) return;
    setState(() => _themeMode = mode);
  }

  Future<void> setDarkMode(bool enabled) async {
    await setThemeMode(enabled ? ThemeMode.dark : ThemeMode.light);
  }

  @override
  void initState() {
    super.initState();
    _database = AppDatabase();
    _themeMode = widget.initialThemeMode;
    _initRepositories();
    ApiService().onSessionExpired = _handleSessionExpired;
    _loadSession();
  }

  void _handleSessionExpired() {
    FcmService.instance.clearUserSession();
    if (!mounted || _session == null) return;
    setState(() => _session = null);
  }

  void _initRepositories() {
    _orderRepository = OrderRepository(db: _database);
    _productRepository = ProductRepository(_database);
    _customerRepository = CustomerRepository(db: _database);
    _authRepository = AuthRepository();
  }

  Future<void> _loadSession() async {
    setState(() {
      _session = ApiService().currentUser;
      _isLoading = false;
    });
  }

  Future<void> _saveSession(Map<String, dynamic> session) async {
    if (mounted) {
      setState(() => _session = session);
    }
  }

  void updateSession(Map<String, dynamic> session) {
    if (mounted) {
      setState(() => _session = Map<String, dynamic>.from(session));
    }
  }

  Future<void> _logout() async {
    if (mounted) {
      setState(() => _session = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: _database),
        ProxyProvider<AppDatabase, LocalRepository>(
          update: (_, db, __) => LocalRepository(db),
        ),
        ChangeNotifierProvider(create: (_) {
          final authProvider = AuthProvider(_authRepository);
          final user = ApiService().currentUser;
          if (user != null) {
            authProvider.updateUser(User.fromJson(user));
          }
          return authProvider;
        }),
        ChangeNotifierProvider(create: (_) => OrdersProvider(_orderRepository)),
        ChangeNotifierProvider(
            create: (_) => OrderDetailProvider(_orderRepository)),
        ChangeNotifierProvider(
            create: (_) => ProductsProvider(_productRepository)),
        ChangeNotifierProvider(
            create: (_) => CustomerProvider(_customerRepository)),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider(NotificationService()),
        ),
        ChangeNotifierProxyProvider<LocalRepository, DraftsProvider>(
          create: (context) => DraftsProvider(context.read<LocalRepository>()),
          update: (context, localRepo, previous) =>
              previous ?? DraftsProvider(localRepo),
        ),
      ],
      child: MaterialApp(
        navigatorKey: DeepLinkService.navigatorKey,
        title: 'Orca Order',
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          final theme = Theme.of(context);
          final statusBarColor =
              theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;
          final isDark = theme.brightness == Brightness.dark;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: statusBarColor,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
              systemNavigationBarColor: theme.colorScheme.surface,
              systemNavigationBarIconBrightness:
                  isDark ? Brightness.light : Brightness.dark,
            ),
            child: SafeArea(
              bottom: true,
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: _themeMode,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ar'),
          Locale('en'),
        ],
        locale: const Locale('ar'),
        home: _session == null
            ? LoginPage(onLoginSuccess: _saveSession)
            : _mustChangePassword(_session!)
                ? ForcePasswordChangeScreen(onComplete: _logout)
                : HomePage(session: _session!, onLogout: _logout),
      ),
    );
  }

  bool _mustChangePassword(Map<String, dynamic> session) {
    final value = session['must_change_password'];
    return value == true ||
        value == 1 ||
        const {'1', 'true', 'yes'}.contains(value?.toString().toLowerCase());
  }
}
