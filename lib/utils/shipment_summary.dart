import 'dart:convert';

class ShipmentSummary {
  static List<Map<String, dynamic>> packageTypes(
      Map<String, dynamic> shipment) {
    final raw = shipment['package_types_json'] ?? shipment['package_types'];
    if (raw is List) {
      final parsed = raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((item) => _count(item['count']) > 0)
          .toList();
      if (parsed.isNotEmpty) return parsed;
    }

    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final parsed = decoded
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .where((item) => _count(item['count']) > 0)
              .toList();
          if (parsed.isNotEmpty) return parsed;
        }
      } on FormatException {
        // Old rows may contain arbitrary text; fall back to their numeric fields.
      }
    }

    final legacy = <Map<String, dynamic>>[];
    final cartons = _count(shipment['carton_count']);
    final bags = _count(shipment['bag_count']);
    if (cartons > 0) {
      legacy.add({'type': 'carton', 'label': 'كرتونة', 'count': cartons});
    }
    if (bags > 0) {
      legacy.add({'type': 'bag', 'label': 'كيس', 'count': bags});
    }
    return legacy;
  }

  static int total(Map<String, dynamic> shipment) {
    final types = packageTypes(shipment);
    if (types.isNotEmpty) {
      return types.fold<int>(0, (sum, item) => sum + _count(item['count']));
    }
    return _count(shipment['package_count']);
  }

  static String format(Map<String, dynamic> shipment) {
    final count = total(shipment);
    if (count == 0) return 'لا توجد طرود مسجلة';

    final types = packageTypes(shipment);
    final details = types
        .map((item) => _formatType(item))
        .where((value) => value.isNotEmpty)
        .toList();
    final noun = count == 1
        ? 'طرد واحد'
        : count == 2
            ? 'طردان'
            : count <= 10
                ? 'طرود'
                : 'طردًا';
    return '$count $noun${details.isEmpty ? '' : ' (${details.join('، ')})'}';
  }

  static String formatAll(Map<String, dynamic> shipmentData) {
    final rawShipments = shipmentData['all_shipments'];
    if (rawShipments is! List) return format(shipmentData);
    final summaries = rawShipments
        .whereType<Map>()
        .map((item) => format(Map<String, dynamic>.from(item)))
        .where((summary) => summary != 'لا توجد طرود مسجلة')
        .toList();
    return summaries.join('؛ ');
  }

  static String _formatType(Map<String, dynamic> item) {
    final count = _count(item['count']);
    if (count <= 0) return '';
    final type = item['type']?.toString();
    final label =
        (item['label'] ?? item['custom_type'])?.toString().trim() ?? '';
    switch (type) {
      case 'carton':
        final noun = count == 1
            ? 'كرتونة'
            : count == 2
                ? 'كرتونتان'
                : count <= 10
                    ? 'كراتين'
                    : 'كرتونة';
        return '$count $noun';
      case 'bag':
        final noun = count == 1
            ? 'كيس'
            : count == 2
                ? 'كيسان'
                : count <= 10
                    ? 'أكياس'
                    : 'كيس';
        return '$count $noun';
      default:
        return label.isEmpty ? '' : '$count $label';
    }
  }

  static int _count(dynamic value) {
    if (value is int) return value > 0 ? value : 0;
    if (value is num) {
      return value.isFinite && value > 0 && value == value.round()
          ? value.toInt()
          : 0;
    }
    return int.tryParse(value?.toString().trim() ?? '') ?? 0;
  }
}
