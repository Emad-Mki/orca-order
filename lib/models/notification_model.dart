class NotificationModel {
  final String id;
  final String eventType;
  final String title;
  final String body;
  final String? targetRole;
  final String? targetUserId;
  final String? customerId;
  final String? orderId;
  final String? invoiceId;
  final String? productId;
  final String deepLink;
  final DateTime? createdAt;
  final DateTime? sentAt;
  final DateTime? readAt;
  final bool isRead;
  final String status;
  final String? lastError;
  final int retryCount;

  const NotificationModel({
    required this.id,
    required this.eventType,
    required this.title,
    required this.body,
    required this.deepLink,
    required this.isRead,
    required this.status,
    this.lastError,
    this.retryCount = 0,
    this.targetRole,
    this.targetUserId,
    this.customerId,
    this.orderId,
    this.invoiceId,
    this.productId,
    this.createdAt,
    this.sentAt,
    this.readAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null || value.toString().isEmpty) return null;
      return DateTime.tryParse(value.toString());
    }

    final readAt = parseDate(json['read_at']);
    final isRead = json['is_read'] == true ||
        json['is_read']?.toString().toLowerCase() == 'true' ||
        json['is_read']?.toString() == '1' ||
        readAt != null ||
        json['status'] == 'read';

    return NotificationModel(
      id: (json['notification_id'] ?? json['id'] ?? '').toString(),
      eventType: (json['event_type'] ?? json['type'] ?? 'general').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      targetRole: json['target_role']?.toString(),
      targetUserId: (json['target_user_id'] ?? json['user_id'])?.toString(),
      customerId: json['customer_id']?.toString(),
      orderId: _nonEmpty(json['order_id']),
      invoiceId: _nonEmpty(json['invoice_id']),
      productId: _nonEmpty(json['product_id']),
      deepLink: (json['deep_link'] ?? json['screenRoute'] ?? '').toString(),
      createdAt: parseDate(json['created_at']),
      sentAt: parseDate(json['sent_at']),
      readAt: readAt,
      isRead: isRead,
      status: (json['status'] ?? (isRead ? 'read' : 'sent')).toString(),
      lastError: json['last_error']?.toString(),
      retryCount: int.tryParse((json['retry_count'] ?? 0).toString()) ?? 0,
    );
  }

  static String? _nonEmpty(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  Map<String, dynamic> toJson() => {
        'notification_id': id,
        'event_type': eventType,
        'title': title,
        'body': body,
        'target_role': targetRole,
        'target_user_id': targetUserId,
        'customer_id': customerId,
        'order_id': orderId,
        'invoice_id': invoiceId,
        'product_id': productId,
        'deep_link': deepLink,
        'created_at': createdAt?.toIso8601String(),
        'sent_at': sentAt?.toIso8601String(),
        'read_at': readAt?.toIso8601String(),
        'is_read': isRead,
        'status': status,
        'last_error': lastError,
        'retry_count': retryCount,
      };

  NotificationModel copyWith({
    String? id,
    String? eventType,
    String? title,
    String? body,
    String? targetRole,
    String? targetUserId,
    String? customerId,
    String? orderId,
    String? invoiceId,
    String? productId,
    String? deepLink,
    DateTime? createdAt,
    DateTime? sentAt,
    DateTime? readAt,
    bool? isRead,
    String? status,
    String? lastError,
    int? retryCount,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      eventType: eventType ?? this.eventType,
      title: title ?? this.title,
      body: body ?? this.body,
      targetRole: targetRole ?? this.targetRole,
      targetUserId: targetUserId ?? this.targetUserId,
      customerId: customerId ?? this.customerId,
      orderId: orderId ?? this.orderId,
      invoiceId: invoiceId ?? this.invoiceId,
      productId: productId ?? this.productId,
      deepLink: deepLink ?? this.deepLink,
      createdAt: createdAt ?? this.createdAt,
      sentAt: sentAt ?? this.sentAt,
      readAt: readAt ?? this.readAt,
      isRead: isRead ?? this.isRead,
      status: status ?? this.status,
      lastError: lastError ?? this.lastError,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}
