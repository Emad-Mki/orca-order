import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// شاشة الشحن
class ShippingScreen extends StatefulWidget {
  const ShippingScreen({super.key});

  @override
  State<ShippingScreen> createState() => _ShippingScreenState();
}

class _ShippingScreenState extends State<ShippingScreen> {
  List<dynamic> _shipments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchShipments();
  }

  Future<void> _fetchShipments() async {
    setState(() => _isLoading = true);
    try {
      final session = context.findAncestorStateOfType<_HomePageState>()?.widget.session;
      final data = await ApiService().post({
        'action': 'getShipments',
        'username': session?['username'],
        'token': session?['token'],
      });
      if (mounted) {
        setState(() {
          _shipments = data['shipments'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateShipmentStatus(String id, String newStatus) async {
    try {
      await ApiService().post({
        'action': 'updateShipmentStatus',
        'shipmentId': id,
        'status': newStatus,
      });
      _fetchShipments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'in_transit': return Icons.local_shipping;
      case 'delivered': return Icons.check_circle;
      case 'returned': return Icons.assignment_return;
      default: return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _shipments.length,
      itemBuilder: (context, index) {
        final s = _shipments[index];
        final status = s['status']?.toString() ?? '';
        return Card(
          child: ListTile(
            leading: Icon(_getStatusIcon(status), 
              color: status == 'delivered' ? Colors.green : (status == 'returned' ? Colors.red : Colors.blue)),
            title: Text('شحنة #${s['shipment_id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('طلب: ${s['order_id']} | الناقل: ${s['carrier']}\nتتبع: ${s['tracking_no']}'),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.edit_note),
              onSelected: (val) => _updateShipmentStatus(s['shipment_id'], val),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'in_transit', child: Text('قيد النقل')),
                const PopupMenuItem(value: 'delivered', child: Text('تم التسليم')),
                const PopupMenuItem(value: 'returned', child: Text('مرتجع')),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
