import 'package:flutter/material.dart';

/// ويدجت أزرار إجراءات الطلب - يعرض الأزرار المتاحة حسب الحالة والدور
class OrderActionsWidget extends StatelessWidget {
  final String status;
  final String role;
  final VoidCallback? onPrice;
  final VoidCallback? onApprove;
  final VoidCallback? onPrepare;
  final VoidCallback? onShip;
  final VoidCallback? onDeliver;
  final VoidCallback? onCancel;
  final VoidCallback? onEdit;
  final VoidCallback? onPrint;

  const OrderActionsWidget({
    super.key,
    required this.status,
    required this.role,
    this.onPrice,
    this.onApprove,
    this.onPrepare,
    this.onShip,
    this.onDeliver,
    this.onCancel,
    this.onEdit,
    this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    final canManage = role == 'admin' || role == 'manager' || role == 'accountant';
    final isCustomer = role == 'customer';
    final isWarehouse = role == 'warehouse';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          // أزرار المحاسب/المدير
          if (canManage && _isPricableStatus(status))
            _buildActionButton(context, 'تسعير الفاتورة', Icons.attach_money, Colors.blue, onPrice),
          
          if (canManage && _isApprovableStatus(status))
            _buildActionButton(context, 'اعتماد الطلب', Icons.check_circle, Colors.green, onApprove),
          
          if (canManage && _isPreparableStatus(status))
            _buildActionButton(context, 'تجهيز الطلب', Icons.inventory_2, Colors.orange, onPrepare),
          
          if (canManage && _isShippableStatus(status))
            _buildActionButton(context, 'شحن', Icons.local_shipping, Colors.indigo, onShip),
          
          if (canManage && _isDeliverableStatus(status))
            _buildActionButton(context, 'تسليم', Icons.delivery_dining, Colors.teal, onDeliver),
          
          if (canManage && _isCancellableStatus(status))
            _buildActionButton(context, 'إلغاء', Icons.cancel, Colors.red, onCancel),

          // أزرار الزبون
          if (isCustomer && _isEditableStatus(status))
            _buildActionButton(context, 'تعديل الطلب', Icons.edit, Colors.blue, onEdit),
          
          if (isCustomer && _isConfirmableStatus(status))
            _buildActionButton(context, 'موافق على السعر', Icons.check, Colors.green, onApprove),

          // أزرار المستودع
          if (isWarehouse && _isPreparableStatus(status))
            _buildActionButton(context, 'بدء التجهيز', Icons.inventory_2, Colors.orange, onPrepare),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback? onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  bool _isPricableStatus(String status) {
    return ['pending', 'submitted', 'customer_changed'].contains(status);
  }

  bool _isApprovableStatus(String status) {
    return ['priced', 'customer_confirmed'].contains(status);
  }

  bool _isPreparableStatus(String status) {
    return ['approved', 'customer_confirmed'].contains(status);
  }

  bool _isShippableStatus(String status) {
    return ['prepared'].contains(status);
  }

  bool _isDeliverableStatus(String status) {
    return ['shipping'].contains(status);
  }

  bool _isCancellableStatus(String status) {
    return !['delivered', 'cancelled'].contains(status);
  }

  bool _isEditableStatus(String status) {
    return ['pending', 'submitted'].contains(status);
  }

  bool _isConfirmableStatus(String status) {
    return ['priced', 'customer_changed'].contains(status);
  }
}
