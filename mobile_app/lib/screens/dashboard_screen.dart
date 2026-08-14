import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'nav_item.dart';

/// الشاشة الرئيسية (Dashboard)
class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  const DashboardScreen({super.key, required this.session});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _stats = [];
  List<dynamic> _latestNotifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final params = {
        'username': widget.session['username'],
        'token': widget.session['token'],
      };

      final statsData = await ApiService().post({'action': 'getDashboardStats', ...params});
      final notifData = await ApiService().post({'action': 'getNotifications', ...params});

      if (mounted) {
        setState(() {
          _stats = statsData['stats'] ?? [];
          _latestNotifications = (notifData['notifications'] as List? ?? []).take(3).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _fetchDashboardData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('نظرة عامة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xff00658f))),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _stats.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemBuilder: (context, index) {
              final s = _stats[index];
              return _buildStatCard(
                s['title'] ?? '',
                s['value'] ?? '',
                _getIconData(s['icon']),
                _getStatColor(index),
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('آخر الإشعارات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  // الانتقال لصفحة الإشعارات
                  final homeState = context.findAncestorStateOfType<StatefulWidget>();
                  // ملاحظة: نحتاج للوصول لـ HomePage لتحديث _selectedIndex
                },
                child: const Text('عرض الكل'),
              ),
            ],
          ),
          if (_latestNotifications.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('لا توجد تحديثات جديدة')),
            )
          else
            ..._latestNotifications.map((n) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.notifications_none, color: Colors.orange),
                title: Text(n['title'] ?? ''),
                subtitle: Text(n['body'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () {
                  // يمكن فتح تفاصيل الإشعار هنا
                },
              ),
            )),
        ],
      ),
    );
  }

  IconData _getIconData(String? iconName) {
    switch (iconName) {
      case 'shopping_cart': return Icons.shopping_cart;
      case 'account_balance_wallet': return Icons.account_balance_wallet;
      case 'person': return Icons.person;
      case 'people': return Icons.people;
      case 'attach_money': return Icons.attach_money;
      case 'inventory': return Icons.inventory;
      case 'new_releases': return Icons.new_releases;
      default: return Icons.info;
    }
  }

  Color _getStatColor(int index) {
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.red, Colors.purple, Colors.teal];
    return colors[index % colors.length];
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
