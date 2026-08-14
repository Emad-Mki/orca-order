import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;

import 'services/api_service.dart';
import 'repositories/order_repository.dart';
import 'models/models.dart';
import 'screens/screens.dart';

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
  State<OrcaApp> createState() => _OrcaAppState();
}

class _OrcaAppState extends State<OrcaApp> {
  Map<String, dynamic>? _session;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSession();
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

    return MaterialApp(
      title: 'Orca Order',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Tajawal',
      ),
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
    );
  }
}
