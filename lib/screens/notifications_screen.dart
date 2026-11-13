import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/notification_model.dart';
import '../providers/notification_provider.dart';
import '../services/deep_link_service.dart';
import '../services/api_service.dart';
import '../widgets/notification_tile.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _filter = 'all';

  bool _matchesFilter(NotificationModel notification) {
    if (_filter == 'all') return true;
    final event = notification.eventType.toLowerCase();
    switch (_filter) {
      case 'orders':
        return event.startsWith('order');
      case 'invoices':
        return event.startsWith('invoice') ||
            event.startsWith('payment') ||
            event.startsWith('account');
      case 'warehouse':
        return event.startsWith('warehouse') || event.startsWith('inventory');
      case 'shipping':
        return event.startsWith('shipping');
      case 'alerts':
        return event.startsWith('alert');
      default:
        return true;
    }
  }

  Future<void> _open(NotificationModel notification) async {
    final provider = context.read<NotificationProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final currentUserId =
        ApiService().currentUser?['user_id']?.toString() ?? '';
    if (['failed', 'pending'].contains(notification.status) &&
        notification.targetUserId != currentUserId) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(notification.lastError ?? 'تعذر إرسال الإشعار'),
        ),
      );
      return;
    }
    final marked = await provider.markRead(notification.id);
    if (!marked && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(provider.error ?? 'تعذر تحديث حالة الإشعار')),
      );
    }
    if (mounted) {
      await DeepLinkService.openNotification(notification.toJson());
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final visible = provider.notifications.where(_matchesFilter).toList();
    final isAdmin =
        ApiService().currentUser?['role']?.toString().toLowerCase() == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          if (provider.unreadCount > 0)
            TextButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final success = await provider.markAllRead();
                if (!success && mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(provider.error ?? 'تعذر تحديث الإشعارات'),
                    ),
                  );
                }
              },
              child: const Text('تعليم الكل كمقروء'),
            ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip('all', 'الكل'),
                _filterChip('orders', 'الطلبات'),
                _filterChip('invoices', 'الفواتير'),
                _filterChip('warehouse', 'المستودع'),
                _filterChip('shipping', 'الشحن'),
                _filterChip('alerts', 'التنبيهات'),
              ],
            ),
          ),
          if (provider.error != null)
            MaterialBanner(
              content: Text(provider.error!),
              actions: [
                TextButton(
                  onPressed: () => context.read<NotificationProvider>().load(),
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: provider.load,
              child: provider.isLoading && provider.notifications.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(height: 180),
                        Center(child: CircularProgressIndicator()),
                      ],
                    )
                  : visible.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 180),
                            Center(child: Text('لا توجد إشعارات')),
                          ],
                        )
                      : ListView.builder(
                          itemCount: visible.length,
                          itemBuilder: (context, index) => NotificationTile(
                            notification: visible[index],
                            onTap: () => _open(visible[index]),
                            onRetry: isAdmin &&
                                    ['failed', 'pending']
                                        .contains(visible[index].status)
                                ? () async {
                                    final retryProvider =
                                        context.read<NotificationProvider>();
                                    final messenger =
                                        ScaffoldMessenger.of(context);
                                    final success = await retryProvider
                                        .retry(visible[index].id);
                                    if (!success && mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(provider.error ??
                                              'تعذرت إعادة الإرسال'),
                                        ),
                                      );
                                    }
                                  }
                                : null,
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ChoiceChip(
          label: Text(label),
          selected: _filter == value,
          onSelected: (_) => setState(() => _filter = value),
        ),
      );
}
