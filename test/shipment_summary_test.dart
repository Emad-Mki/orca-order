import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/utils/shipment_summary.dart';

void main() {
  group('ShipmentSummary', () {
    test('formats typed package totals and omits zero types', () {
      expect(
        ShipmentSummary.format({
          'package_types_json': [
            {'type': 'carton', 'label': 'كرتونة', 'count': 1},
            {'type': 'bag', 'label': 'كيس', 'count': 1},
            {'type': 'custom', 'label': 'لفة', 'count': 1},
            {'type': 'carton', 'label': 'كرتونة', 'count': 0},
          ],
        }),
        '3 طرود (1 كرتونة، 1 كيس، 1 لفة)',
      );
    });

    test('handles singular, dual and plural totals', () {
      expect(ShipmentSummary.format({'package_count': 1}), '1 طرد واحد');
      expect(ShipmentSummary.format({'package_count': 2}), '2 طردان');
      expect(ShipmentSummary.format({'package_count': 4}), '4 طرود');
      expect(ShipmentSummary.format({'package_count': 12}), '12 طردًا');
    });

    test('reads legacy carton and bag counts and total-only rows', () {
      expect(
        ShipmentSummary.format({
          'package_count': 3,
          'carton_count': 1,
          'bag_count': 2,
        }),
        '3 طرود (1 كرتونة، 2 كيسان)',
      );
      expect(ShipmentSummary.format({'package_count': 6}), '6 طرود');
    });

    test('combines multiple partial shipments for an invoice', () {
      expect(
        ShipmentSummary.formatAll({
          'all_shipments': [
            {
              'package_types': [
                {'type': 'carton', 'label': 'كرتونة', 'count': 1},
              ],
            },
            {'package_count': 2},
          ],
        }),
        '1 طرد واحد (1 كرتونة)؛ 2 طردان',
      );
    });
  });
}
