import 'product.dart';

/// نموذج صنف الطلب
class OrderItem {
  final String itemId;
  final String code;
  final String name;
  final String unit;
  final double quantityRequested;
  final double quantityApproved;
  final double quantityPrepared;
  final double priceOffer;
  final double defaultPrice;
  final double finalPrice;
  final String currency;
  final String status;
  final String? customerNote;
  final String? accountantNote;
  final String? warehouseNote;
  final int stockAvailable;
  final String? imageUrl;
  final String? imageFileId;
  final String? imageName;

  // Additional fields for local cart handling
  final Product? product;
  double? quantity;
  String? note;
  String? selectedUnit;

  OrderItem({
    required this.itemId,
    required this.code,
    required this.name,
    required this.unit,
    required this.quantityRequested,
    required this.quantityApproved,
    required this.quantityPrepared,
    required this.priceOffer,
    required this.defaultPrice,
    required this.finalPrice,
    required this.currency,
    required this.status,
    this.customerNote,
    this.accountantNote,
    this.warehouseNote,
    required this.stockAvailable,
    this.imageUrl,
    this.imageFileId,
    this.imageName,
    this.product,
    this.quantity,
    this.note,
    this.selectedUnit,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    // تحسين قراءة الأسعار - التحقق من حقول متعددة وبترتيب محدد
    double parsePrice(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      
      String str = value.toString().trim();
      if (str.isEmpty || str.toLowerCase() == 'null') return 0.0;
      
      // إزالة الرموز غير الرقمية
      str = str.replaceAll(',', '')
               .replaceAll('\$', '')
               .replaceAll('USD', '')
               .replaceAll('SYP', '')
               .replaceAll(' ', '');
      
      return double.tryParse(str) ?? 0.0;
    }

    return OrderItem(
      itemId: json['item_id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name'] ?? 'منتج غير معروف',
      unit: json['unit'] ?? '',
      quantityRequested: parsePrice(json['quantity_requested']),
      quantityApproved: parsePrice(json['quantity_approved']),
      quantityPrepared: parsePrice(json['quantity_prepared']),
      priceOffer: parsePrice(json['price_offer'] ?? json['display_price_snapshot']),
      defaultPrice: parsePrice(json['default_price']),
      finalPrice: parsePrice(json['final_price']),
      currency: json['currency'] ?? 'USD',
      status: json['status'] ?? '',
      customerNote: json['customer_note'],
      accountantNote: json['accountant_note'],
      warehouseNote: json['warehouse_note'],
      stockAvailable: json['stock_available'] ?? 0,
      imageUrl: json['image_url'],
      imageFileId: json['image_file_id'],
      imageName: json['image_name'],
    );
  }

  /// للحالات التي ننشئ فيها صنف من منتج (السلة)
  factory OrderItem.fromProduct(Product product, {double quantity = 1.0, String? note, String? selectedUnit}) {
    return OrderItem(
      itemId: '',
      code: product.code ?? '',
      name: product.name ?? '',
      unit: product.unit ?? '',
      quantityRequested: quantity,
      quantityApproved: 0,
      quantityPrepared: 0,
      priceOffer: product.price ?? 0,
      defaultPrice: product.price ?? 0,
      finalPrice: 0,
      currency: 'USD',
      status: 'pending',
      stockAvailable: product.stock ?? 0,
      imageUrl: product.imageUrl,
      product: product,
      quantity: quantity,
      note: note,
      selectedUnit: selectedUnit ?? product.unit,
    );
  }

  /// الحصول على السعر الفعلي للعرض
  /// الأولوية: final_price > price_offer > default_price
  double get displayPrice {
    if (finalPrice > 0) return finalPrice;
    if (priceOffer > 0) return priceOffer;
    return defaultPrice;
  }

  /// حساب الإجمالي بناءً على الكمية المعتمدة أو المطلوبة
  double get total {
    if (product != null && quantity != null) {
      return (product!.price ?? 0) * quantity!;
    }
    double qty = quantityApproved > 0 ? quantityApproved : quantityRequested;
    return displayPrice * qty;
  }

  /// التحقق مما إذا كان الصنف غير متوفر
  bool get isUnavailable {
    return status.toLowerCase() == 'unavailable' || 
           status.toLowerCase() == 'not_available';
  }

  Map<String, dynamic> toJson() => {
    'item_id': itemId,
    'code': code,
    'name': name,
    'unit': unit,
    'quantity_requested': quantityRequested,
    'quantity_approved': quantityApproved,
    'quantity_prepared': quantityPrepared,
    'price_offer': priceOffer,
    'default_price': defaultPrice,
    'final_price': finalPrice,
    'currency': currency,
    'status': status,
    'customer_note': customerNote,
    'accountant_note': accountantNote,
    'warehouse_note': warehouseNote,
    'stock_available': stockAvailable,
    'image_url': imageUrl,
    'image_file_id': imageFileId,
    'image_name': imageName,
  };
}
