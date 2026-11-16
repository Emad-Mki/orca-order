import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/utils/number_utils.dart';

void main() {
  test('money formatter includes the selected currency exactly once', () {
    expect(formatMoneyShort(12.345, currency: 'USD'), '12.35 USD');
    expect(
      formatMoneyShort(1234.6, currency: 'SYP', decimalPlaces: 0),
      '1235 SYP',
    );
    expect(
      formatMoney(12, currency: 'USD', decimalPlaces: 0),
      '12 USD',
    );
  });

  test('money parser accepts values carrying a currency code', () {
    expect(toSafeDouble('12.50 USD'), 12.5);
    expect(toSafeDouble('1500 SYP'), 1500);
  });
}
