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
    return id.isNotEmpty &&
        revision.isNotEmpty &&
        productCode == code &&
        unit == selectedUnit &&
        currency.toUpperCase() == itemCurrency.toUpperCase() &&
        isEnabled &&
        status == 'active' &&
        price != null &&
        price! > 0 &&
        minimum != null &&
        minimum! > 0 &&
        quantity >= minimum! &&
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
      data['starts_at'] == other.data['starts_at'] &&
      data['ends_at'] == other.data['ends_at'];
}
