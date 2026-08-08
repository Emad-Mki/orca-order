import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;

import 'app_config.dart';

void main() => runApp(const OrcaApp());

class ApiService {
  Future<Map<String, dynamic>> post(Map<String, dynamic> body) async {
    if (AppConfig.apiUrl.startsWith('PASTE_')) {
      throw Exception('ضع رابط Google Apps Script في AppConfig.apiUrl');
    }
    final res = await http.post(
      Uri.parse(AppConfig.apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['ok'] != true) {
      throw Exception(data['error'] ?? 'خطأ غير معروف من الخادم');
    }
    return data;
  }
}

class OrcaApp extends StatelessWidget {
  const OrcaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xff00658f),
        fontFamily: 'sans',
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ApiService();
      final data = await api.post({
        'action': 'login',
        'username': _userCtrl.text.trim(),
        'password': _passCtrl.text,
      });
      final session = data['session'] as Map<String, dynamic>;
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(session: session),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.settings, size: 72, color: Color(0xff00658f)),
                    const SizedBox(height: 8),
                    Text(
                      AppConfig.companyName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'أوركا أوردر',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _userCtrl,
                      decoration: const InputDecoration(labelText: 'اسم المستخدم'),
                    ),
                    TextField(
                      controller: _passCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'كلمة المرور'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loading ? null : _login,
                      child: Text(_loading ? 'جارٍ تسجيل الدخول...' : 'تسجيل الدخول'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final Map<String, dynamic> session;

  const HomePage({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final role = session['role']?.toString() ?? '';
    final fullName = session['full_name']?.toString() ?? '';

    final pages = <String>[
      'الرئيسية',
      'المنتجات',
      'الطلبات',
      'العملاء',
      'المخزون',
      'الدفعات',
      'الشحن',
      'التقارير',
      'الإعدادات',
    ];

    final allowed = switch (role) {
      'customer' => ['الرئيسية', 'المنتجات', 'الطلبات'],
      'warehouse' => ['الرئيسية', 'المنتجات', 'المخزون', 'الطلبات'],
      _ => pages,
    };

    return _HomeScaffold(
      fullName: fullName,
      role: role,
      allowed: allowed,
      session: session,
    );
  }
}

class _HomeScaffold extends StatefulWidget {
  final String fullName;
  final String role;
  final List<String> allowed;
  final Map<String, dynamic> session;

  const _HomeScaffold({
    required this.fullName,
    required this.role,
    required this.allowed,
    required this.session,
  });

  @override
  State<_HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<_HomeScaffold> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final title = widget.allowed[_index];

    return Scaffold(
      appBar: AppBar(
        title: Text('أوركا أوردر - ${widget.fullName}'),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              child: Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  '${widget.fullName}\nالدور: ${widget.role}',
                  textAlign: TextAlign.right,
                ),
              ),
            ),
            for (var i = 0; i < widget.allowed.length; i++)
              ListTile(
                title: Text(widget.allowed[i]),
                onTap: () {
                  setState(() => _index = i);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
      body: FeaturePlaceholder(title: title, session: widget.session),
    );
  }
}

class FeaturePlaceholder extends StatelessWidget {
  final String title;
  final Map<String, dynamic> session;

  const FeaturePlaceholder({
    super.key,
    required this.title,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final notes = <String>[
      'هذه الشاشة مرتبطة بطبقة Google Apps Script. سيتم توسيعها لاحقاً لكل دور.',
    ];

    if (title == 'المنتجات') {
      notes.add('يعرض البحث بالرمز أو الاسم أو المجموعة، مع سعر عرض للزبون من ملف المنتجات.');
    } else if (title == 'الطلبات') {
      notes.add('تدعم الحالات: مسودة، مرسلة، مسعّرة، موافقة الزبون، معتمدة، قيد التجهيز، مشحونة، مكتملة.');
    } else if (title == 'المخزون') {
      notes.add('يعرض للمستودع الكميات فقط دون أسعار، مع استلام مواد وحركات الجرد.');
    } else if (title == 'الدفعات') {
      notes.add('طرق الدفع: نقدي، حوالة، شام كاش، مع رصيد سابق ورصيد نهائي لكل عميل.');
    } else if (title == 'الشحن') {
      notes.add('شركة الشحن، المحافظة، عدد الطرود، أجور الشحن الداخلية، وحالة التسليم.');
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          for (final n in notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $n'),
            ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'هذه نسخة هيكلية (Skeleton). يمكنك الآن إضافة الشاشات التفصيلية وربطها مع API.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
