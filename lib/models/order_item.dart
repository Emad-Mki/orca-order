import 'product.dart';

/// نموذج صنف الطلب
class OrderItem {
  final String itemId;
  final String code;
  final String name;
  final String unit;
  final double? quantityRequested;
  final double? quantityApproved;
  final double? quantityPrepared;
  final double? priceOffer;
  final double? defaultPrice;
  final double? finalPrice;
  final String currency;
  final String status;
  final String? customerNote;
  final String? accountantNote;
  final String? warehouseNote;
  final String? warehousePackageNumbers;
  final String? warehousePackageType;
  final String? warehouseCustomPackageType;
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
    this.warehousePackageNumbers,
    this.warehousePackageType,
    this.warehouseCustomPackageType,
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
    int parseInt(dynamic value) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    double? parseNullableDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();

      String str = value.toString().trim();
      if (str.isEmpty || str.toLowerCase() == 'null') return null;

      str = str
          .replaceAll(',', '')
          .replaceAll('\$', '')
          .replaceAll('USD', '')
          .replaceAll('SYP', '')
          .replaceAll(' ', '');

      return double.tryParse(str);
    }

    return OrderItem(
      itemId: json['item_id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name'] ?? 'منتج غير معروف',
      unit: json['unit'] ?? '',
      quantityRequested: parseNullableDouble(json['quantity_requested']),
      quantityApproved: parseNullableDouble(json['quantity_approved']),
      quantityPrepared: parseNullableDouble(json['quantity_prepared']),
      priceOffer: parseNullableDouble(
          json['price_offer'] ?? json['display_price_snapshot']),
      defaultPrice: parseNullableDouble(json['default_price']),
      finalPrice: parseNullableDouble(json['final_price']),
      currency: json['currency'] ?? 'USD',
      status: json['status'] ?? '',
      customerNote: json['customer_note'],
      accountantNote: json['accountant_note'],
      warehouseNote: json['warehouse_note'],
      warehousePackageNumbers: json['warehouse_package_numbers']?.toString(),
      warehousePackageType: json['warehouse_package_type']?.toString(),
      warehouseCustomPackageType:
          json['warehouse_custom_package_type']?.toString(),
      stockAvailable: parseInt(json['stock_available']),
      imageUrl: json['image_url'],
      imageFileId: json['image_file_id'],
      imageName: json['image_name'],
    );
  }

  /// للحالات التي ننشئ فيها صنف من منتج (السلة)
  factory OrderItem.fromProduct(Product product,
      {double quantity = 1.0,
      String? note,
      String? selectedUnit,
      double? overridePrice}) {
    return OrderItem(
      itemId: '',
      code: product.code,
      name: product.name,
      unit: product.unit,
      quantityRequested: quantity,
      quantityApproved: 0,
      quantityPrepared: 0,
      priceOffer: overridePrice ?? product.price,
      defaultPrice: product.price,
      finalPrice: 0,
      currency: 'USD',
      status: 'pending',
      stockAvailable: product.stock,
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
    if (finalPrice != null && finalPrice! > 0) return finalPrice!;
    if (priceOffer != null && priceOffer! > 0) return priceOffer!;
    return defaultPrice ?? 0.0;
  }

  double get pricedUnitPrice => finalPrice ?? displayPrice;

  double get pricedQuantity => quantityApproved ?? quantityRequested ?? 0.0;

  double get pricedLineTotal =>
      isUnavailable ? 0.0 : pricedUnitPrice * pricedQuantity;

  /// حساب الإجمالي بناءً على الكمية المعتمدة أو المطلوبة
  double get total {
    if (isUnavailable) return 0.0;
    if (finalPrice != null &&
        (finalPrice! > 0 || status.toLowerCase() == 'available')) {
      return pricedLineTotal;
    }
    if (product != null && quantity != null) {
      return product!.price * quantity!;
    }
    double qty = (quantityApproved != null && quantityApproved! > 0)
        ? quantityApproved!
        : (quantityRequested ?? 0.0);
    return displayPrice * qty;
  }

  /// التحقق مما إذا كان الصنف غير متوفر
  bool get isUnavailable {
    return status.toLowerCase() == 'unavailable' ||
        status.toLowerCase() == 'not_available';
  }

  OrderItem copyWith({
    String? itemId,
    String? code,
    String? name,
    String? unit,
    double? quantityRequested,
    double? quantityApproved,
    double? quantityPrepared,
    double? priceOffer,
    double? defaultPrice,
    double? finalPrice,
    String? currency,
    String? status,
    String? customerNote,
    String? accountantNote,
    String? warehouseNote,
    String? warehousePackageNumbers,
    String? warehousePackageType,
    String? warehouseCustomPackageType,
    int? stockAvailable,
    String? imageUrl,
    String? imageFileId,
    String? imageName,
  }) {
    return OrderItem(
      itemId: itemId ?? this.itemId,
      code: code ?? this.code,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      quantityRequested: quantityRequested ?? this.quantityRequested,
      quantityApproved: quantityApproved ?? this.quantityApproved,
      quantityPrepared: quantityPrepared ?? this.quantityPrepared,
      priceOffer: priceOffer ?? this.priceOffer,
      defaultPrice: defaultPrice ?? this.defaultPrice,
      finalPrice: finalPrice ?? this.finalPrice,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      customerNote: customerNote ?? this.customerNote,
      accountantNote: accountantNote ?? this.accountantNote,
      warehouseNote: warehouseNote ?? this.warehouseNote,
      warehousePackageNumbers:
          warehousePackageNumbers ?? this.warehousePackageNumbers,
      warehousePackageType: warehousePackageType ?? this.warehousePackageType,
      warehouseCustomPackageType:
          warehouseCustomPackageType ?? this.warehouseCustomPackageType,
      stockAvailable: stockAvailable ?? this.stockAvailable,
      imageUrl: imageUrl ?? this.imageUrl,
      imageFileId: imageFileId ?? this.imageFileId,
      imageName: imageName ?? this.imageName,
    );
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
        'warehouse_package_numbers': warehousePackageNumbers,
        'warehouse_package_type': warehousePackageType,
        'warehouse_custom_package_type': warehouseCustomPackageType,
        'stock_available': stockAvailable,
        'image_url': imageUrl,
        'image_file_id': imageFileId,
        'image_name': imageName,
      };
}
