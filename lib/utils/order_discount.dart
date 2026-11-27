import 'dart:math' as math;

class OrderDiscountCalculation {
  final String type;
  final String input;
  final double amount;
  final double subtotal;
  final double netTotal;

  const OrderDiscountCalculation({
    required this.type,
    required this.input,
    required this.amount,
    required this.subtotal,
    required this.netTotal,
  });
}

OrderDiscountCalculation calculateOrderDiscount({
  required String input,
  required double subtotal,
  int currencyDecimals = 2,
}) {
  if (!subtotal.isFinite || subtotal < 0) {
    throw const FormatException('إجمالي الفاتورة غير صالح');
  }
  if (currencyDecimals < 0 || currencyDecimals > 4) {
    throw const FormatException('دقة العملة غير صالحة');
  }
  final roundedSubtotal = roundOrderAmount(subtotal, currencyDecimals);
  final raw = input.trim();
  if (raw.isEmpty) {
    return OrderDiscountCalculation(
      type: 'none',
      input: '',
      amount: 0,
      subtotal: roundedSubtotal,
      netTotal: roundedSubtotal,
    );
  }

  var normalized = raw.replaceAll('٫', '.').replaceAll('٪', '%');
  const digits = {
    '٠': '0',
    '١': '1',
    '٢': '2',
    '٣': '3',
    '٤': '4',
    '٥': '5',
    '٦': '6',
    '٧': '7',
    '٨': '8',
    '٩': '9',
    '۰': '0',
    '۱': '1',
    '۲': '2',
    '۳': '3',
    '۴': '4',
    '۵': '5',
    '۶': '6',
    '۷': '7',
    '۸': '8',
    '۹': '9',
  };
  normalized = normalized.replaceAllMapped(
    RegExp('[${digits.keys.join()}]'),
    (match) => digits[match.group(0)]!,
  );
  if (RegExp(r'\d\s+\d').hasMatch(normalized)) {
    throw const FormatException('المسافات داخل الرقم تجعل قيمة الحسم غامضة');
  }
  normalized = normalized.replaceAll(RegExp(r'[\s\u00a0]'), '');
  final percentMarks = '%'.allMatches(normalized).length;
  final isPercent = percentMarks == 1;
  if (percentMarks > 1 || (percentMarks == 1 && !normalized.endsWith('%'))) {
    throw const FormatException('صيغة الحسم غير واضحة؛ ضع % بعد النسبة');
  }
  if (isPercent) normalized = normalized.substring(0, normalized.length - 1);
  if (normalized.contains(',') && normalized.contains('.')) {
    throw const FormatException(
        'استخدم فاصلة عشرية واحدة فقط، ولا تستخدم فواصل الآلاف');
  }
  final numberPattern = RegExp(r'^\d+(?:[.,]\d{1,2})?$');
  if (!numberPattern.hasMatch(normalized)) {
    throw const FormatException(
        'أدخل رقماً غير سالب مثل 25.50 أو نسبة مثل 10%');
  }
  final value = double.tryParse(normalized.replaceAll(',', '.'));
  if (value == null || !value.isFinite || value < 0) {
    throw const FormatException('قيمة الحسم يجب أن تكون رقماً غير سالب');
  }

  final type = isPercent ? 'percent' : 'amount';
  if (isPercent && value > 100) {
    throw const FormatException('نسبة الحسم يجب أن تكون بين 0 و100%');
  }
  final amount = roundOrderAmount(
    isPercent ? roundedSubtotal * value / 100 : value,
    currencyDecimals,
  );
  if (!isPercent && amount > roundedSubtotal) {
    throw const FormatException('مبلغ الحسم لا يجوز أن يتجاوز إجمالي الفاتورة');
  }
  return OrderDiscountCalculation(
    type: type,
    input: raw.replaceAll(RegExp(r'\s+'), ' ').trim(),
    amount: amount,
    subtotal: roundedSubtotal,
    netTotal: roundOrderAmount(roundedSubtotal - amount, currencyDecimals),
  );
}

double roundOrderAmount(double amount, [int decimals = 2]) {
  final factor = math.pow(10, decimals).toDouble();
  return ((amount + 1e-10) * factor).round() / factor;
}
