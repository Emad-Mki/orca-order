import 'order_item.dart';

/// نموذج الطلب
class Order {
  final String orderId;
  final String orderNumber;
  final String customerId;
  final String customerName;
  final String status;
  final String currency;
  final String? note;
  final String? accountantNotes;
  final String? accountingInvoiceNo;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? createdByRole;
  final bool isNew;
  final bool isRead;
  final double? totalAmount;
  final double? previousBalance;
  final double? currentBalance;
  final double? shippingCost;
  final double? discount;
  final String? clientRequestId;
  final Map<String, dynamic>? shipmentData;
  final List<OrderItem>? items;

  Order({
    required this.orderId,
    required this.orderNumber,
    required this.customerId,
    required this.customerName,
    required this.status,
    required this.currency,
    this.note,
    this.accountantNotes,
    this.accountingInvoiceNo,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.createdByRole,
    this.isNew = false,
    this.isRead = false,
    this.totalAmount,
    this.previousBalance,
    this.currentBalance,
    this.shippingCost,
    this.discount,
    this.clientRequestId,
    this.shipmentData,
    this.items,
  });

  factory Order.fromMap(Map<String, dynamic> map) => Order.fromJson(map);

  factory Order.fromJson(Map<String, dynamic> json) {
    // دالة مساعدة لتحليل التاريخ
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      try {
        return DateTime.parse(value.toString());
      } catch (e) {
        return null;
      }
    }

    // دالة مساعدة لتحليل الأسعار
    double? parseNullablePrice(dynamic value) {
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

    // تحليل العناصر إذا كانت موجودة
    List<OrderItem>? parseItems(dynamic itemsData) {
      if (itemsData == null) return null;
      if (itemsData is! List) return null;
      return itemsData.map((item) => OrderItem.fromJson(item)).toList();
    }

    return Order(
      orderId: json['order_id']?.toString() ?? json['id']?.toString() ?? '',
      orderNumber: json['order_number']?.toString() ??
          json['order_no']?.toString() ??
          json['order_id']?.toString() ??
          '',
      customerId: json['customer_id']?.toString() ?? '',
      customerName: json['customer_name'] ??
          json['full_name'] ??
          json['username'] ??
          'غير معروف',
      status: json['status'] ?? '',
      currency: json['currency'] ?? 'USD',
      note: json['note'],
      accountantNotes: json['accountant_notes'],
      accountingInvoiceNo: json['accounting_invoice_no'],
      createdAt: parseDate(json['created_at'] ?? json['date']),
      updatedAt: parseDate(json['updated_at']),
      createdBy: json['created_by'],
      createdByRole: json['created_by_role']?.toString(),
      isNew: _parseBool(json['is_new']) || _parseBool(json['is_read']) == false,
      isRead: _parseBool(json['is_read']),
      totalAmount: parseNullablePrice(
          json['total_amount'] ?? json['total'] ?? json['grand_total']),
      previousBalance: parseNullablePrice(json['previous_balance']),
      currentBalance:
          parseNullablePrice(json['current_balance'] ?? json['balance']),
      shippingCost:
          parseNullablePrice(json['shipping_cost'] ?? json['shippingCost']),
      discount: parseNullablePrice(json['discount']),
      clientRequestId: json['client_request_id']?.toString(),
      shipmentData: json['shipment_data'] is Map
          ? Map<String, dynamic>.from(json['shipment_data'] as Map)
          : null,
      items: parseItems(json['items'] ?? json['order_items']),
    );
  }

  Order copyWith({
    String? orderId,
    String? orderNumber,
    String? customerId,
    String? customerName,
    String? status,
    String? currency,
    String? note,
    String? accountantNotes,
    String? accountingInvoiceNo,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? createdByRole,
    bool? isNew,
    bool? isRead,
    double? totalAmount,
    double? previousBalance,
    double? currentBalance,
    double? shippingCost,
    double? discount,
    String? clientRequestId,
    Map<String, dynamic>? shipmentData,
    List<OrderItem>? items,
  }) {
    return Order(
      orderId: orderId ?? this.orderId,
      orderNumber: orderNumber ?? this.orderNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      status: status ?? this.status,
      currency: currency ?? this.currency,
      note: note ?? this.note,
      accountantNotes: accountantNotes ?? this.accountantNotes,
      accountingInvoiceNo: accountingInvoiceNo ?? this.accountingInvoiceNo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      createdByRole: createdByRole ?? this.createdByRole,
      isNew: isNew ?? this.isNew,
      isRead: isRead ?? this.isRead,
      totalAmount: totalAmount ?? this.totalAmount,
      previousBalance: previousBalance ?? this.previousBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      shippingCost: shippingCost ?? this.shippingCost,
      discount: discount ?? this.discount,
      clientRequestId: clientRequestId ?? this.clientRequestId,
      shipmentData: shipmentData ?? this.shipmentData,
      items: items ?? this.items,
    );
  }

  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    String str = value.toString().toLowerCase();
    return str == 'true' || str == '1';
  }

  Map<String, dynamic> toJson() => {
        'order_id': orderId,
        'order_number': orderNumber,
        'customer_id': customerId,
        'customer_name': customerName,
        'status': status,
        'currency': currency,
        'note': note,
        'accountant_notes': accountantNotes,
        'accounting_invoice_no': accountingInvoiceNo,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'created_by': createdBy,
        'created_by_role': createdByRole,
        'is_new': isNew,
        'is_read': isRead,
        'total_amount': totalAmount,
        'previous_balance': previousBalance,
        'current_balance': currentBalance,
        'shipping_cost': shippingCost,
        'discount': discount,
        'client_request_id': clientRequestId,
        'shipment_data': shipmentData,
        'items': items?.map((item) => item.toJson()).toList(),
      };
}
