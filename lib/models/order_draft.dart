import 'product.dart';

enum SaveStatus { saving, saved, error, none }

class OrderDraft {
  final int? id;
  final String customerId;
  final String customerName;
  final String? note;
  final DateTime updatedAt;
  final List<DraftItem> items;
  final String currency;
  final String? customTitle;

  OrderDraft({
    this.id,
    required this.customerId,
    required this.customerName,
    this.note,
    required this.updatedAt,
    required this.items,
    this.currency = 'USD',
    this.customTitle,
  });

  double get total {
    return items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
  }
}

class DraftItem {
  final int? id;
  final String productCode;
  final String productName;
  final String unit;
  final double quantity;
  final double price;
  final String? note;
  final Product? originalProduct; // Snapshot for alerts if changed

  DraftItem({
    this.id,
    required this.productCode,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.price,
    this.note,
    this.originalProduct,
  });
}
