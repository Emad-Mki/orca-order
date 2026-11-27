import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/utils/order_discount.dart';

void main() {
  test('calculates percentage and amount discounts from the subtotal', () {
    final percentage = calculateOrderDiscount(
      input: '١٠ %',
      subtotal: 100,
    );
    expect(percentage.type, 'percent');
    expect(percentage.amount, 10);
    expect(percentage.netTotal, 90);

    final amount = calculateOrderDiscount(
      input: '٢٥٫٥٠',
      subtotal: 100,
    );
    expect(amount.type, 'amount');
    expect(amount.amount, 25.5);
    expect(amount.netTotal, 74.5);

    expect(
      calculateOrderDiscount(input: '25,50', subtotal: 100).amount,
      25.5,
    );
  });

  test('rounds using invoice precision and treats empty input as no discount',
      () {
    final noDiscount = calculateOrderDiscount(input: '', subtotal: 12.345);
    expect(noDiscount.amount, 0);
    expect(noDiscount.netTotal, 12.35);

    final rounded = calculateOrderDiscount(
      input: '10%',
      subtotal: 99.99,
    );
    expect(rounded.amount, 10);
    expect(rounded.netTotal, 89.99);
  });

  test('rejects negative, ambiguous, malformed, and excessive discounts', () {
    for (final input in [
      '-1',
      '101%',
      '1,000',
      '1.000,00',
      '1 000',
      '10%%',
      'abc',
    ]) {
      expect(
        () => calculateOrderDiscount(input: input, subtotal: 100),
        throwsFormatException,
        reason: input,
      );
    }

    expect(
      () => calculateOrderDiscount(input: '101', subtotal: 100),
      throwsFormatException,
    );
  });
}
