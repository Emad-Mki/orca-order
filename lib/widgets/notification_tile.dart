import 'package:flutter/material.dart';

import '../models/notification_model.dart';

class NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback? onRetry;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
    this.onRetry,
  });

  IconData get _icon {
    if (notification.eventType.startsWith('order')) {
      return Icons.assignment_outlined;
    }
    if (notification.eventType.startsWith('invoice') ||
        notification.eventType.startsWith('payment') ||
        notification.eventType.startsWith('account')) {
      return Icons.receipt_long_outlined;
    }
    if (notification.eventType.startsWith('warehouse') ||
        notification.eventType.startsWith('inventory')) {
      return Icons.inventory_2_outlined;
    }
    if (notification.eventType.startsWith('shipping')) {
      return Icons.local_shipping_outlined;
    }
    if (notification.eventType.startsWith('alert')) {
      return Icons.warning_amber_outlined;
    }
    return Icons.notifications_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: notification.isRead
              ? theme.colorScheme.surfaceContainerHighest
              : theme.colorScheme.primaryContainer,
          child: Icon(_icon, color: theme.colorScheme.primary),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight:
                notification.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (['failed', 'pending'].contains(notification.status) &&
                notification.lastError?.isNotEmpty == true)
              Text(
                notification.status == 'failed'
                    ? 'فشل الإرسال: ${notification.lastError}'
                    : 'الإرسال معلّق: ${notification.lastError}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
          ],
        ),
        trailing: ['failed', 'pending'].contains(notification.status) &&
                onRetry != null
            ? IconButton(
                tooltip: 'إعادة الإرسال',
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
              )
            : notification.isRead
                ? null
                : Icon(Icons.circle,
                    size: 10, color: theme.colorScheme.primary),
        isThreeLine:
            notification.status == 'failed' && notification.lastError != null,
      ),
    );
  }
}
