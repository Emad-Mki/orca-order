import 'product.dart';
import 'order_offer.dart';

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
  final double? savedLineTotal;
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
  final OrderOffer? offer;
  final double? expectedUnitPrice;

  // New fields for multi-unit and historical tracking
  final double?
      unitFactor; // The conversion factor for the selected unit at time of order
  final double? basePriceSnapshot; // The base price (Unit 1) at time of order
  final String? unit1;
  final double? factor2;
  final String? unit2;
  final double? factor3;
  final String? unit3;

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
    this.savedLineTotal,
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
    this.offer,
    this.expectedUnitPrice,
    this.unitFactor,
    this.basePriceSnapshot,
    this.unit1,
    this.factor2,
    this.unit2,
    this.factor3,
    this.unit3,
    this.product,
    this.quantity,
    this.note,
    this.selectedUnit,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    String textValue(dynamic value, {String fallback = ''}) =>
        value is String ? value : fallback;

    String identifierValue(dynamic value) {
      if (value is String) return value;
      if (value is num) return value.toString();
      return '';
    }

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
      itemId: identifierValue(json['item_id']),
      code: identifierValue(json['code']),
      name: textValue(json['name'], fallback: 'منتج غير معروف'),
      unit: textValue(json['unit']),
      quantityRequested: parseNullableDouble(json['quantity_requested']),
      quantityApproved: parseNullableDouble(json['quantity_approved']),
      quantityPrepared: parseNullableDouble(json['quantity_prepared']),
      priceOffer: parseNullableDouble(
          json['price_offer'] ?? json['display_price_snapshot']),
      defaultPrice: parseNullableDouble(json['default_price']),
      finalPrice: parseNullableDouble(json['final_price']),
      savedLineTotal: parseNullableDouble(json['total_price']),
      currency: textValue(json['currency'], fallback: 'USD'),
      status: textValue(json['status']),
      customerNote: _nullableText(json['customer_note']),
      accountantNote: _nullableText(json['accountant_note']),
      warehouseNote: _nullableText(json['warehouse_note']),
      warehousePackageNumbers: _nullableText(json['warehouse_package_numbers']),
      warehousePackageType: _nullableText(json['warehouse_package_type']),
      warehouseCustomPackageType: _nullableText(
        json['warehouse_custom_package_type'],
      ),
      stockAvailable: parseInt(json['stock_available']),
      imageUrl: _nullableText(json['image_url']),
      imageFileId: _nullableText(json['image_file_id']),
      imageName: _nullableText(json['image_name']),
      offer: json['offer_snapshot'] is Map
          ? OrderOffer(Map<String, dynamic>.from(json['offer_snapshot']))
          : identifierValue(json['offer_id']).trim().isNotEmpty
              ? OrderOffer({
                  'offer_id': identifierValue(json['offer_id']),
                  if (json.containsKey('offer_revision'))
                    'revision': json['offer_revision'],
                  if (json.containsKey('code')) 'product_code': json['code'],
                  if (json.containsKey('unit')) 'unit': json['unit'],
                  if (json.containsKey('currency'))
                    'currency': json['currency'],
                  if (json.containsKey('unit_price_snapshot'))
                    'offer_price': json['unit_price_snapshot'],
                  if (json.containsKey('offer_old_price'))
                    'old_price': json['offer_old_price'],
                  if (json.containsKey('offer_min_quantity'))
                    'min_quantity': json['offer_min_quantity'],
                  if (json.containsKey('offer_starts_at'))
                    'starts_at': json['offer_starts_at'],
                  if (json.containsKey('offer_ends_at'))
                    'ends_at': json['offer_ends_at'],
                })
              : null,
      expectedUnitPrice: parseNullableDouble(json['expected_unit_price']),
      unitFactor: parseNullableDouble(json['unit_factor']),
      basePriceSnapshot: parseNullableDouble(json['base_price_snapshot']),
      unit1: _nullableText(json['unit_1']),
      factor2: parseNullableDouble(json['factor_2']),
      unit2: _nullableText(json['unit_2']),
      factor3: parseNullableDouble(json['factor_3']),
      unit3: _nullableText(json['unit_3']),
    );
  }

  static String? _nullableText(dynamic value) =>
      value is String && value.isNotEmpty ? value : null;

  /// للحالات التي ننشئ فيها صنف من منتج (السلة)
  factory OrderItem.fromProduct(Product product,
      {double quantity = 1.0,
      String? note,
      String? selectedUnit,
      double? overridePrice,
      OrderOffer? offer,
      double? expectedUnitPrice}) {
    final unit = selectedUnit?.trim().isNotEmpty == true
        ? selectedUnit!.trim()
        : product.unit;
    final factor = product.factorForUnit(unit);
    final unitPrice = product.priceForUnit(unit);

    return OrderItem(
      itemId: '',
      code: product.code,
      name: product.name,
      unit: unit,
      quantityRequested: quantity,
      quantityApproved: 0,
      quantityPrepared: 0,
      priceOffer: overridePrice ?? unitPrice,
      defaultPrice: unitPrice,
      finalPrice: null,
      currency: product.currency,
      status: 'pending',
      stockAvailable: product.stock,
      imageUrl: product.imageUrl,
      offer: offer,
      expectedUnitPrice: expectedUnitPrice,
      unitFactor: factor,
      basePriceSnapshot: product.price,
      unit1: product.unit,
      factor2: product.factor2,
      unit2: product.unit2,
      factor3: product.factor3,
      unit3: product.unit3,
      product: product,
      quantity: quantity,
      note: note,
      selectedUnit: unit,
    );
  }

  /// الحصول على السعر الفعلي للعرض
  /// الأولوية: final_price > price_offer > default_price
  bool get offerBelowMinimum =>
      offer?.minimumFor(code, selectedUnit ?? unit) != null &&
      quantity != null &&
      quantity! < offer!.minimumFor(code, selectedUnit ?? unit)!;

  double get displayPrice {
    if (offerBelowMinimum) return defaultPrice ?? 0;
    return finalPrice ?? priceOffer ?? defaultPrice ?? 0.0;
  }

  double get pricedUnitPrice => finalPrice ?? displayPrice;
  bool get hasConfiguredUnitPrice => offerBelowMinimum
      ? defaultPrice != null
      : finalPrice != null || priceOffer != null || defaultPrice != null;
  bool get hasConfiguredUnitConversion =>
      unitFactor != null && unitFactor!.isFinite && unitFactor! > 0;

  double get pricedQuantity => quantityApproved ?? quantityRequested ?? 0.0;

  double get pricedLineTotal =>
      isUnavailable ? 0.0 : pricedUnitPrice * pricedQuantity;

  /// حساب الإجمالي بناءً على الكمية المعتمدة أو المطلوبة
  double get total {
    if (isUnavailable) return 0.0;
    final isUnsubmittedCartItem =
        quantity != null && status.toLowerCase() == 'pending';
    final qty = isUnsubmittedCartItem ? quantity! : pricedQuantity;
    if (offerBelowMinimum) return (defaultPrice ?? 0) * qty;
    if (finalPrice != null) return finalPrice! * qty;
    if (priceOffer != null) return priceOffer! * qty;
    if (defaultPrice != null) return defaultPrice! * qty;
    return 0;
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
    double? savedLineTotal,
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
    OrderOffer? offer,
    double? expectedUnitPrice,
    double? unitFactor,
    double? basePriceSnapshot,
    String? unit1,
    double? factor2,
    String? unit2,
    double? factor3,
    String? unit3,
    Product? product,
    double? quantity,
    String? note,
    String? selectedUnit,
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
      savedLineTotal: savedLineTotal ?? this.savedLineTotal,
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
      offer: offer ?? this.offer,
      expectedUnitPrice: expectedUnitPrice ?? this.expectedUnitPrice,
      unitFactor: unitFactor ?? this.unitFactor,
      basePriceSnapshot: basePriceSnapshot ?? this.basePriceSnapshot,
      unit1: unit1 ?? this.unit1,
      factor2: factor2 ?? this.factor2,
      unit2: unit2 ?? this.unit2,
      factor3: factor3 ?? this.factor3,
      unit3: unit3 ?? this.unit3,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
      selectedUnit: selectedUnit ?? this.selectedUnit,
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
        'total_price': savedLineTotal,
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
        if (offer != null) ...{
          'offer_id': offer!.id,
          'offer_revision': offer!.revision,
          'offer_price': offer!.priceFor(code, selectedUnit ?? unit),
          'offer_snapshot': offer!.data,
        },
        if (expectedUnitPrice != null) 'expected_unit_price': expectedUnitPrice,
        'unit_factor': unitFactor,
        'base_price_snapshot': basePriceSnapshot,
        'unit_1': unit1,
        'factor_2': factor2,
        'unit_2': unit2,
        'factor_3': factor3,
        'unit_3': unit3,
      };
}
