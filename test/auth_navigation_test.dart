import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/main.dart';
import 'package:orca_order/screens/homepage_screen.dart';
import 'package:orca_order/screens/login_page.dart';
import 'package:orca_order/screens/force_password_change_screen.dart';
import 'package:orca_order/services/api_service.dart';
import 'package:orca_order/services/deep_link_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('login and logout update the visible root without restart',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const OrcaApp());
    await tester.pump();
    expect(find.byType(LoginPage), findsOneWidget);

    tester.widget<LoginPage>(find.byType(LoginPage)).onLoginSuccess({
      'user_id': 'customer-1',
      'role': 'customer',
      'full_name': 'Customer',
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);

    final logout = tester.widget<HomePage>(find.byType(HomePage)).onLogout;
    DeepLinkService.navigatorKey.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('private route')),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('private route'), findsOneWidget);
    logout();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
    expect(find.text('private route'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('password change and session expiration replace the root',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const OrcaApp());
    await tester.pump();
    tester.widget<LoginPage>(find.byType(LoginPage)).onLoginSuccess({
      'user_id': 'customer-1',
      'role': 'customer',
      'must_change_password': true,
    });
    await tester.pump();
    expect(find.byType(ForcePasswordChangeScreen), findsOneWidget);
    tester
        .widget<ForcePasswordChangeScreen>(find.byType(ForcePasswordChangeScreen))
        .onComplete();
    await tester.pump();
    expect(find.byType(LoginPage), findsOneWidget);
    tester.widget<LoginPage>(find.byType(LoginPage)).onLoginSuccess({
      'user_id': 'customer-1',
      'role': 'customer',
    });
    await tester.pump();
    expect(find.byType(HomePage), findsOneWidget);
    ApiService().onSessionExpired!();
    await tester.pump();
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
