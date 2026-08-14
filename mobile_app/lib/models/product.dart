/// نموذج المنتج
class Product {
  final int? id;
  final String code;
  final String name;
  final String category;
  final String origin;
  final String unit;
  final double price;
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
    required this.origin,
    required this.unit,
    required this.price,
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
    this.units,
    this.uomName,
    this.factor2,
    this.unit2,
    this.factor3,
    this.unit3,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    var unitsData = json['units'];
    List<String>? unitsList;
    if (unitsData is List) {
      unitsList = unitsData.map((u) => u.toString()).toList();
    } else if (unitsData is String) {
      unitsList = unitsData.split(',').map((u) => u.trim()).toList();
    }
    
    if (unitsList == null || unitsList.isEmpty) {
      unitsList = [];
      String u1 = json['unit'] ?? json['unit_1'] ?? '';
      if (u1.isNotEmpty) unitsList.add(u1);
      String u2 = json['unit_2']?.toString() ?? '';
      if (u2.isNotEmpty) unitsList.add(u2);
      String u3 = json['unit_3']?.toString() ?? '';
      if (u3.isNotEmpty) unitsList.add(u3);
    }
    
    // تحسين قراءة السعر - التحقق من حقول متعددة
    dynamic priceValue = json['price'] ?? 
                         json['display_price'] ?? 
                         json['final_price'] ?? 
                         json['price_offer'] ?? 
                         0;
    
    return Product(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      code: json['code']?.toString() ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? json['group'] ?? '',
      origin: json['origin'] ?? '',
      unit: json['unit'] ?? json['unit_1'] ?? '',
      price: _parsePrice(priceValue),
      offerPrice: json['offer_price'] != null ? _parsePrice(json['offer_price']) : null,
      quantity: (json['quantity'] ?? 0).toDouble(),
      stockQuantity: json['stock_quantity'] != null ? (json['stock_quantity'] as num).toDouble() : (json['stock_available'] ?? json['stock'] ?? 0).toDouble(),
      minOrderQuantity: json['min_order_quantity'] != null ? (json['min_order_quantity'] as num).toDouble() : 1.0,
      brand: json['brand']?.toString(),
      isActive: json['is_active'] == true || json['is_active'] == 1 || json['is_active'] == '1',
      imageUrl: json['image_url'],
      imageFileId: json['image_file_id'],
      imageName: json['image_name'],
      notes: json['notes'],
      currency: json['currency'] ?? 'USD',
      stock: (json['stock_available'] ?? json['stock'] ?? 0).toInt(),
      description: json['description'],
      units: unitsList,
      uomName: json['uomName']?.toString(),
      factor2: (json['factor_2'] ?? 1.0).toDouble(),
      unit2: json['unit_2']?.toString(),
      factor3: (json['factor_3'] ?? 1.0).toDouble(),
      unit3: json['unit_3']?.toString(),
    );
  }

  /// دالة مساعدة لتحليل السعر بشكل آمن
  static double _parsePrice(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    
    String str = value.toString().trim();
    if (str.isEmpty) return 0.0;
    
    // إزالة الرموز غير الرقمية
    str = str.replaceAll(',', '')
             .replaceAll('\$', '')
             .replaceAll('USD', '')
             .replaceAll('SYP', '')
             .replaceAll(' ', '');
    
    return double.tryParse(str) ?? 0.0;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'category': category,
    'origin': origin,
    'unit': unit,
    'price': price,
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
    'units': units,
    'uomName': uomName,
    'factor_2': factor2,
    'unit_2': unit2,
    'factor_3': factor3,
    'unit_3': unit3,
  };
}
