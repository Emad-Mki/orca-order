import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/services/guide_coordinator.dart';
import 'package:orca_order/widgets/guided_tour.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('guide controls work with RTL, dark mode and enlarged text',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    GuideCoordinator.ready = true;
    addTearDown(() {
      GuideCoordinator.interrupt();
      GuideCoordinator.ready = false;
    });
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(2)),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        ),
      ),
      home: GuidedTour(
        accountId: 'accessibility',
        name: 'accessibility',
        targetCount: 2,
        ready: true,
        builder: (context, target) => Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                target(
                    0,
                    'اختر الزبون وأدخل الدفعات في نموذج الفاتورة، ثم راجعها قبل الحفظ.',
                    const Text('الهدف الأول')),
                const SizedBox(height: 50),
                target(1, 'الخطوة الثانية', const Text('الهدف الثاني')),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
        find.text(
            'اختر الزبون وأدخل الدفعات في نموذج الفاتورة، ثم راجعها قبل الحفظ.'),
        findsOneWidget);
    await tester.tap(find.text('التالي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('الخطوة الثانية'), findsOneWidget);
    await tester.tap(find.text('السابق'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
        find.text(
            'اختر الزبون وأدخل الدفعات في نموذج الفاتورة، ثم راجعها قبل الحفظ.'),
        findsOneWidget);
    await tester.tap(find.text('تخطي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('guide.accessibility.v1.accessibility'), 'skipped');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
