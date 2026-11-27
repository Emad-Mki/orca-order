import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/models/product.dart';
import 'package:orca_order/utils/smart_product_search.dart';

Product product({
  required String code,
  required String name,
  String group = '',
  String origin = '',
}) {
  return Product(
    code: code,
    name: name,
    category: group,
    group: group,
    origin: origin,
    unit: 'قطعة',
    price: 1,
  );
}

void main() {
  final handle = product(
    code: 'A-123',
    name: 'مسكة باب مارسيدس',
    group: 'قطع الغيار',
    origin: 'ألمانيا',
  );

  test('matches separated words and word initials in Arabic', () {
    final index = SmartProductSearchIndex([
      product(code: 'B-10', name: 'باب بي ام دبليو'),
      handle,
    ]);

    expect(index.search('مسكة مارسيدس'), contains(handle));
    expect(index.search('مس با ما').first, handle);
    expect(index.search('مارسيدس مسكة').first, handle);
  });

  test('normalizes Arabic letters, diacritics and Arabic numerals', () {
    final indexed = product(
      code: '١٢٣',
      name: 'مَسْكَة باب مرسيدس',
      group: 'أجزاء',
      origin: 'مصر',
    );
    final index = SmartProductSearchIndex([indexed]);

    expect(index.search('مسكه 123'), contains(indexed));
    expect(index.search('اجزاء'), contains(indexed));
  });

  test('prioritizes exact product codes and excludes unrelated results', () {
    final exactCode = product(code: 'MS-1', name: 'قطعة مختلفة');
    final nameMatch = product(code: 'OTHER', name: 'مسكة باب');
    final index = SmartProductSearchIndex([
      nameMatch,
      product(code: 'THIRD', name: 'غير مرتبط'),
      exactCode,
    ]);

    expect(index.search('MS-1').first, exactCode);
    expect(index.search('مسكة باب'), [nameMatch]);
    expect(index.search('مجهول'), isEmpty);
  });
}
