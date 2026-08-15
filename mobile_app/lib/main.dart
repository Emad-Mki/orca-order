import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:io' show Platform;

import 'repositories/repositories.dart';
import 'models/models.dart';
import 'screens/screens.dart';
import 'providers/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(const OrcaApp());
}

/// تطبيق Orca Order الرئيسي
class OrcaApp extends StatefulWidget {
  const OrcaApp({super.key});

  @override
  State<OrcaApp> createState() => OrcaAppState();
}

class OrcaAppState extends State<OrcaApp> {
  Map<String, dynamic>? _session;
  bool _isLoading = true;
  ThemeMode _themeMode = ThemeMode.light;

  // Repositories (will be injected into providers)
  late OrderRepository _orderRepository;
  late ProductRepository _productRepository;
  late CustomerRepository _customerRepository;
  late AuthRepository _authRepository;

  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  void initState() {
    super.initState();
    _initRepositories();
    _loadSession();
  }

  void _initRepositories() {
    _orderRepository = OrderRepository();
    _productRepository = ProductRepository();
    _customerRepository = CustomerRepository();
    _authRepository = AuthRepository();
  }

  Future<void> _loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = prefs.getString('session');
      if (sessionJson != null) {
        setState(() {
          _session = json.decode(sessionJson);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading session: \$e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSession(Map<String, dynamic> session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session', json.encode(session));
    if (mounted) {
      setState(() => _session = session);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session');
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
        ChangeNotifierProvider(create: (_) => AuthProvider(_authRepository)),
        ChangeNotifierProvider(create: (_) => OrdersProvider(_orderRepository)),
        ChangeNotifierProvider(create: (_) => OrderDetailProvider(_orderRepository)),
        ChangeNotifierProvider(create: (_) => ProductsProvider(_productRepository)),
        ChangeNotifierProvider(create: (_) => CustomerProvider(_customerRepository)),
      ],
      child: MaterialApp(
        title: 'Orca Order',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          fontFamily: 'Tajawal',
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          fontFamily: 'Tajawal',
          brightness: Brightness.dark,
        ),
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
            : HomePage(session: _session!, onLogout: _logout),
      ),
    );
  }
}
