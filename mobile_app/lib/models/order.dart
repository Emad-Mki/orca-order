/// نموذج الطلب
class Order {
  final String orderId;
  final String orderNumber;
  final String customerId;
  final String customerName;
  final String status;
  final String currency;
  final String? note;
  final String? accountingInvoiceNo;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final bool isNew;
  final bool isRead;
  final double totalAmount;
  final double previousBalance;
  final double currentBalance;
  final List<OrderItem>? items;

  Order({
    required this.orderId,
    required this.orderNumber,
    required this.customerId,
    required this.customerName,
    required this.status,
    required this.currency,
    this.note,
    this.accountingInvoiceNo,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.isNew = false,
    this.isRead = false,
    this.totalAmount = 0.0,
    this.previousBalance = 0.0,
    this.currentBalance = 0.0,
    this.items,
  });

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
    double parsePrice(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      String str = value.toString().trim();
      if (str.isEmpty || str.toLowerCase() == 'null') return 0.0;
      str = str.replaceAll(',', '').replaceAll('\$', '').replaceAll('USD', '').replaceAll('SYP', '').replaceAll(' ', '');
      return double.tryParse(str) ?? 0.0;
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
                   json['order_id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      customerName: json['customer_name'] ?? 
                    json['full_name'] ?? 
                    json['username'] ?? 
                    'غير معروف',
      status: json['status'] ?? '',
      currency: json['currency'] ?? 'USD',
      note: json['note'],
      accountingInvoiceNo: json['accounting_invoice_no'],
      createdAt: parseDate(json['created_at'] ?? json['date']),
      updatedAt: parseDate(json['updated_at']),
      createdBy: json['created_by'],
      isNew: _parseBool(json['is_new']) || _parseBool(json['is_read']) == false,
      isRead: _parseBool(json['is_read']),
      totalAmount: parsePrice(json['total_amount'] ?? json['total'] ?? json['grand_total']),
      previousBalance: parsePrice(json['previous_balance']),
      currentBalance: parsePrice(json['current_balance'] ?? json['balance']),
      items: parseItems(json['items'] ?? json['order_items']),
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
    'accounting_invoice_no': accountingInvoiceNo,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'created_by': createdBy,
    'is_new': isNew,
    'is_read': isRead,
    'total_amount': totalAmount,
    'previous_balance': previousBalance,
    'current_balance': currentBalance,
    'items': items?.map((item) => item.toJson()).toList(),
  };
}
