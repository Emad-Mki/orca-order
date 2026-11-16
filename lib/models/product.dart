/// نموذج المنتج
class Product {
  final int? id;
  final String code;
  final String name;
  final String category;
  final String group;
  final String subGroup;
  final String origin;
  final String oem;
  final String unit;
  final String? availabilityStatus;
  final double price;
  final bool priceConfigured;
  final double? price2;
  final double? price3;
  final double? offerPrice;
  final double quantity;
  final double? stockQuantity;
  final double? minOrderQuantity;
  final String? brand;
  final bool? isActive;
  final String? imageUrl;
  final String? imageFileId;
  final String? imageName;
  final String? notes;
  final String currency;
  final int stock;
  final String? description;
  final DateTime? createdAt;
  final List<String>? units;
  final String? uomName;

  final double? factor2;
  final String? unit2;
  final double? factor3;
  final String? unit3;

  Product({
    this.id,
    required this.code,
    required this.name,
    required this.category,
    String? group,
    this.subGroup = '',
    required this.origin,
    this.oem = '',
    required this.unit,
    this.availabilityStatus,
    required this.price,
    this.priceConfigured = true,
    this.price2,
    this.price3,
    this.offerPrice,
    this.quantity = 0,
    this.stockQuantity,
    this.minOrderQuantity,
    this.brand,
    this.isActive,
    this.imageUrl,
    this.imageFileId,
    this.imageName,
    this.notes,
    this.currency = 'USD',
    this.stock = 0,
    this.description,
    this.createdAt,
    this.units,
    this.uomName,
    this.factor2,
    this.unit2,
    this.factor3,
    this.unit3,
  }) : group = group ?? category;

  factory Product.fromJson(Map<String, dynamic> json) {
    final stockValue = json['stock_quantity'] ??
        json['stock_available'] ??
        json['stock'] ??
        json['quantity'];

    String? cleanUnit(dynamic value) {
      final unit = value?.toString().trim() ?? '';
      return unit.isEmpty ? null : unit;
    }

    double? parseOptionalPrice(dynamic value) {
      if (value == null) return null;
      var text = value.toString().trim();
      if (text.isEmpty || text.toLowerCase() == 'null') return null;
      text = text
          .replaceAll(',', '')
          .replaceAll('\$', '')
          .replaceAll('USD', '')
          .replaceAll('SYP', '')
          .replaceAll(' ', '');
      return double.tryParse(text);
    }

    var unitsData = json['units'];
    List<String>? unitsList;
    if (unitsData is List) {
      unitsList = unitsData
          .map((u) => u.toString().trim())
          .where((unit) => unit.isNotEmpty)
          .toList();
    } else if (unitsData is String) {
      unitsList = unitsData
          .split(',')
          .map((u) => u.trim())
          .where((unit) => unit.isNotEmpty)
          .toList();
    }

    if (unitsList == null || unitsList.isEmpty) {
      unitsList = [];
      for (final unit in [
        cleanUnit(json['unit_1'] ?? json['unit']),
        cleanUnit(json['unit_2']),
        cleanUnit(json['unit_3']),
      ]) {
        if (unit != null) unitsList.add(unit);
      }
    }

    final priceValue = json['price'] ??
        json['display_price'] ??
        json['final_price'] ??
        json['price_offer'];

    return Product(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      code: json['code']?.toString() ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? json['group'] ?? '',
      group: json['group']?.toString() ?? json['category']?.toString() ?? '',
      subGroup:
          json['sub_group']?.toString() ?? json['subGroup']?.toString() ?? '',
      origin: json['origin'] ?? '',
      oem: json['oem']?.toString() ?? json['OEM']?.toString() ?? '',
      unit: cleanUnit(json['unit_1'] ?? json['unit']) ?? '',
      availabilityStatus: json['availability_status']?.toString(),
      price: parseOptionalPrice(priceValue) ?? 0,
      priceConfigured: json['price_configured'] == false
          ? false
          : parseOptionalPrice(priceValue) != null,
      price2: parseOptionalPrice(json['price_2']),
      price3: parseOptionalPrice(json['price_3']),
      offerPrice:
          json['offer_price'] != null ? _parsePrice(json['offer_price']) : null,
      quantity: (json['quantity'] ?? 0).toDouble(),
      stockQuantity: stockValue is num
          ? stockValue.toDouble()
          : double.tryParse(stockValue?.toString().trim() ?? ''),
      minOrderQuantity: json['min_order_quantity'] is num
          ? (json['min_order_quantity'] as num).toDouble()
          : double.tryParse(
              json['min_order_quantity']?.toString().trim() ?? ''),
      brand: json['brand']?.toString(),
      isActive: json['is_active'] == true ||
          json['is_active'] == 1 ||
          json['is_active'] == '1',
      imageUrl: json['image_url'],
      imageFileId: json['image_file_id'],
      imageName: json['image_name'],
      notes: json['notes'],
      currency: json['currency'] ?? 'USD',
      stock: stockValue is num
          ? stockValue.toInt()
          : int.tryParse(stockValue?.toString().trim() ?? '') ?? 0,
      description: json['description'],
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      units: unitsList,
      uomName: json['uomName']?.toString(),
      factor2: _parseOptionalNumber(json['factor_2']),
      unit2: cleanUnit(json['unit_2']),
      factor3: _parseOptionalNumber(json['factor_3']),
      unit3: cleanUnit(json['unit_3']),
    );
  }

  List<String> get availableUnits {
    final sourceUnits = units ??
        [unit, unit2, unit3].whereType<String>().toList(growable: false);
    final seen = <String>{};
    return sourceUnits
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty && seen.add(value))
        .toList(growable: false);
  }

  double? priceForUnit(String selectedUnit) {
    if (selectedUnit == unit) return priceConfigured ? price : null;
    if (selectedUnit == unit2) return price2;
    if (selectedUnit == unit3) return price3;
    return null;
  }

  double? factorForUnit(String selectedUnit) {
    if (selectedUnit == unit) return 1;
    if (selectedUnit == unit2) return factor2;
    if (selectedUnit == unit3) return factor3;
    return null;
  }

  bool get hasConflictingUnits {
    final seen = <String, (double?, double?)>{};
    final candidates = <(String, double?, double?)>[
      (unit, priceForUnit(unit), factorForUnit(unit)),
      if (unit2?.isNotEmpty == true)
        (unit2!, priceForUnit(unit2!), factorForUnit(unit2!)),
      if (unit3?.isNotEmpty == true)
        (unit3!, priceForUnit(unit3!), factorForUnit(unit3!)),
    ];
    for (final candidate in candidates) {
      final previous = seen[candidate.$1];
      final current = (candidate.$2, candidate.$3);
      if (previous != null && previous != current) return true;
      seen[candidate.$1] = current;
    }
    return false;
  }

  /// دالة مساعدة لتحليل السعر بشكل آمن
  static double _parsePrice(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();

    String str = value.toString().trim();
    if (str.isEmpty) return 0.0;

    // إزالة الرموز غير الرقمية
    str = str
        .replaceAll(',', '')
        .replaceAll('\$', '')
        .replaceAll('USD', '')
        .replaceAll('SYP', '')
        .replaceAll(' ', '');

    return double.tryParse(str) ?? 0.0;
  }

  static double? _parseOptionalNumber(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim());
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'category': category,
        'group': group,
        'sub_group': subGroup,
        'origin': origin,
        'oem': oem,
        'unit': unit,
        'availability_status': availabilityStatus,
        'price': price,
        'price_configured': priceConfigured,
        'price_2': price2,
        'price_3': price3,
        'offer_price': offerPrice,
        'quantity': quantity,
        'stock_quantity': stockQuantity,
        'min_order_quantity': minOrderQuantity,
        'brand': brand,
        'is_active': isActive,
        'image_url': imageUrl,
        'image_file_id': imageFileId,
        'image_name': imageName,
        'notes': notes,
        'currency': currency,
        'stock': stock,
        'description': description,
        'created_at': createdAt?.toIso8601String(),
        'units': units,
        'uomName': uomName,
        'factor_2': factor2,
        'unit_2': unit2,
        'factor_3': factor3,
        'unit_3': unit3,
      };
}
