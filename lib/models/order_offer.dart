import 'dart:convert';

/// An offer snapshot is never authoritative until refreshed from the server.
class OrderOffer {
  final Map<String, dynamic> data;

  OrderOffer(Map<String, dynamic> data) : data = Map.unmodifiable(data);

  String get id => (data['offer_id'] ?? '').toString().trim();
  String get productCode => (data['product_code'] ?? '').toString().trim();
  String get unit => (data['unit'] ?? '').toString().trim();
  String get currency => (data['currency'] ?? '').toString().trim();
  String get revision => (data['revision'] ?? '').toString().trim();
  double? get price => _number(data['offer_price']);
  double? get minimum => _number(data['min_quantity']);
  List<Map<String, dynamic>> get bundleItems {
    final value = data['bundle_items'];
    if (value is! List) return const [];
    return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  bool get isBundle => bundleItems.length > 1;

  double? priceFor(String code, String selectedUnit) {
    if (!isBundle) {
      return productCode == code && unit == selectedUnit ? price : null;
    }
    for (final item in bundleItems) {
      if (item['product_code']?.toString() == code &&
          item['unit']?.toString() == selectedUnit) {
        return _number(item['offer_price']);
      }
    }
    return null;
  }

  double? minimumFor(String code, String selectedUnit) {
    if (!isBundle) return minimum;
    for (final item in bundleItems) {
      if (item['product_code']?.toString() == code &&
          item['unit']?.toString() == selectedUnit) {
        return _number(item['quantity']);
      }
    }
    return null;
  }

  static double? _number(dynamic value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    return number != null && number.isFinite ? number : null;
  }

  bool usableFor({
    required String code,
    required String selectedUnit,
    required String itemCurrency,
    required double quantity,
    required DateTime serverTime,
  }) {
    final enabled = data['enabled'];
    final isEnabled = enabled == true ||
        enabled == 1 ||
        enabled.toString().toLowerCase() == 'true' ||
        enabled.toString() == '1';
    final status = (data['status'] ?? '').toString().trim().toLowerCase();
    final starts = DateTime.tryParse((data['starts_at'] ?? '').toString());
    final ends = DateTime.tryParse((data['ends_at'] ?? '').toString());
    final itemPrice = priceFor(code, selectedUnit);
    final componentMinimum = minimumFor(code, selectedUnit);
    return id.isNotEmpty &&
        revision.isNotEmpty &&
        itemPrice != null &&
        itemPrice > 0 &&
        currency.toUpperCase() == itemCurrency.toUpperCase() &&
        isEnabled &&
        status == 'active' &&
        componentMinimum != null &&
        componentMinimum > 0 &&
        quantity >= componentMinimum &&
        (!isBundle ||
            (quantity / componentMinimum).isFinite &&
                (quantity / componentMinimum) ==
                    (quantity / componentMinimum).roundToDouble()) &&
        starts != null &&
        ends != null &&
        !serverTime.isBefore(starts) &&
        serverTime.isBefore(ends);
  }

  bool sameTerms(OrderOffer other) =>
      id == other.id &&
      revision == other.revision &&
      productCode == other.productCode &&
      unit == other.unit &&
      currency.toUpperCase() == other.currency.toUpperCase() &&
      price == other.price &&
      minimum == other.minimum &&
      jsonEncode(bundleItems) == jsonEncode(other.bundleItems) &&
      data['starts_at'] == other.data['starts_at'] &&
      data['ends_at'] == other.data['ends_at'];
}
