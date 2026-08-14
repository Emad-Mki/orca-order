import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// شاشة الإشعارات
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final session = context.findAncestorStateOfType<_HomePageState>()?.widget.session;
      final data = await ApiService().post({
        'action': 'getNotifications',
        'username': session?['username'],
        'token': session?['token'],
      });
      if (mounted) {
        setState(() {
          _notifications = data['notifications'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleNotificationTap(Map<String, dynamic> n) {
    if (n['read_at'] == null || n['read_at'].toString().isEmpty) {
      _markAsRead(n['notification_id']);
    }

    final String title = n['title']?.toString() ?? '';
    final String body = n['body']?.toString() ?? '';
    final session = context.findAncestorStateOfType<_HomePageState>()?.widget.session;

    if (session == null) return;

    // التنقل الذكي بناءً على المحتوى
    if (body.contains('OR-')) {
      final orderId = RegExp(r'OR-\d+-\d+').stringMatch(body) ?? RegExp(r'OR-\d+').stringMatch(body);
      if (orderId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailsScreen(order: {'id': orderId}, session: session),
          ),
        );
      }
    } else if (title.contains('مخزون') || title.contains('نواقص')) {
      // الانتقال لصفحة المخزون (يجب أن تكون متاحة في الهيكل)
      // إذا كان زبون، ربما نكتفي بعرض الرسالة
    } else if (title.contains('دفعة') || title.contains('حساب')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CustomerStatementScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchNotifications,
        child: Column(
          children: [
            // شريط علوي مع زر اختبار الإشعارات
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _showTestNotification,
                    icon: const Icon(Icons.notifications_active),
                    label: const Text('تجربة إشعار'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _requestPermission,
                    icon: const Icon(Icons.settings),
                    label: const Text('الصلاحيات'),
                  ),
                ],
              ),
            ),
            if (_notifications.isEmpty)
              const Expanded(child: Center(child: Text('لا توجد إشعارات حالياً')))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final n = _notifications[index];
                    final bool isRead = n['read_at'] != null && n['read_at'].toString().isNotEmpty;
                    
                    // أيقونات مخصصة حسب العنوان
                    IconData icon = Icons.notifications;
                    Color iconColor = Colors.blue;
                    if (n['title'].contains('تسعير') || n['title'].contains('فاتورة')) {
                      icon = Icons.receipt_long;
                      iconColor = Colors.green;
                    } else if (n['title'].contains('شحن') || n['title'].contains('تجهيز')) {
                      icon = Icons.local_shipping;
                      iconColor = Colors.orange;
                    } else if (n['title'].contains('نقص')) {
                      icon = Icons.warning_amber_rounded;
                      iconColor = Colors.red;
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      elevation: isRead ? 0 : 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isRead ? BorderSide(color: Colors.grey.shade300) : BorderSide.none,
                      ),
                      color: isRead ? Colors.grey.shade50 : Colors.white,
                      child: ListTile(
                        onTap: () => _handleNotificationTap(n),
                        leading: CircleAvatar(
                          backgroundColor: iconColor.withOpacity(isRead ? 0.2 : 1),
                          child: Icon(icon, color: isRead ? iconColor : Colors.white, size: 20),
                        ),
                        title: Text(
                          n['title'] ?? '',
                          style: TextStyle(
                            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                            color: isRead ? Colors.grey.shade700 : Colors.black,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n['body'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(
                              n['created_at']?.toString().split('T')[0] ?? '',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                        trailing: !isRead 
                          ? Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green))
                          : const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTestNotification() async {
    final appState = context.findAncestorStateOfType<_OrcaAppState>();
    if (appState == null) return;

    const androidDetails = AndroidNotificationDetails(
      'order_updates_channel',
      'تحديثات الطلبات',
      channelDescription: 'إشعارات حول تغيير حالة الطلبات',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await appState.flutterLocalNotificationsPlugin.show(
      id: 0,
      title: 'إشعار تجريبي',
      body: 'هذا إشعار تجريبي لاختبار نظام الإشعارات',
      notificationDetails: details,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال الإشعار التجريبي')),
      );
    }
  }

  Future<void> _requestPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (status.isDenied) {
        await Permission.notification.request();
      } else if (status.isPermanentlyDenied) {
        openAppSettings();
      }
    }

    if (mounted) {
      final status = await Permission.notification.status;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status.isGranted 
            ? 'تم منح صلاحية الإشعارات ✓' 
            : 'لم يتم منح صلاحية الإشعارات ✗'),
          backgroundColor: status.isGranted ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  Future<void> _markAsRead(dynamic notificationId) async {
    try {
      final session = context.findAncestorStateOfType<_HomePageState>()?.widget.session;
      await ApiService().post({
        'action': 'markNotificationRead',
        'notification_id': notificationId,
        'username': session?['username'],
        'token': session?['token'],
      });
      // تحديث الحالة محلياً إذا نجحت العملية
      setState(() {
        final index = _notifications.indexWhere((n) => n['notification_id'] == notificationId);
        if (index != -1) {
          _notifications[index]['read_at'] = DateTime.now().toIso8601String();
        }
      });
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }
}
