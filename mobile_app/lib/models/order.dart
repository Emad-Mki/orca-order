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
  };
}
