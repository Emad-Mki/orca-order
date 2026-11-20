import 'package:flutter/material.dart';
import '../../utils/permissions.dart';
import '../../utils/order_edit_policy.dart';

/// ويدجت أزرار إجراءات الطلب - يعرض الأزرار المتاحة حسب الحالة والدور
class OrderActionsWidget extends StatelessWidget {
  final String status;
  final AppRole userRole;
  final VoidCallback? onPrice;
  final VoidCallback? onApprove;
  final VoidCallback? onPrepare;
  final VoidCallback? onShip;
  final VoidCallback? onDeliver;
  final VoidCallback? onCancel;
  final VoidCallback? onEdit;
  final VoidCallback? onPrint;
  final VoidCallback? onProxyCustomerConfirm;
  final bool isBusy;

  const OrderActionsWidget({
    super.key,
    required this.status,
    required this.userRole,
    this.onPrice,
    this.onApprove,
    this.onPrepare,
    this.onShip,
    this.onDeliver,
    this.onCancel,
    this.onEdit,
    this.onPrint,
    this.onProxyCustomerConfirm,
    this.isBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPrice =
        PermissionHelper.hasPermission(userRole, AppPermission.priceOrder);
    final canApprove =
        PermissionHelper.hasPermission(userRole, AppPermission.approveOrder);
    final canPrepare =
        PermissionHelper.hasPermission(userRole, AppPermission.prepareOrder);
    final canShip =
        PermissionHelper.hasPermission(userRole, AppPermission.shipOrder);
    final canCancel =
        PermissionHelper.hasPermission(userRole, AppPermission.cancelOrder);
    final canEdit = OrderEditPolicy.canEdit(userRole, status) &&
        (userRole == AppRole.warehouse ||
            PermissionHelper.hasPermission(userRole, AppPermission.editOrder));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.12),
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
          // أزرار الإدارة (تسعير، اعتماد، إلخ)
          if (canPrice && _isPricableStatus(status))
            _buildActionButton(context, 'تسعير الفاتورة', Icons.attach_money,
                Colors.blue, isBusy ? null : onPrice),

          if (canApprove && _isApprovableStatus(status))
            _buildActionButton(context, 'اعتماد الطلب', Icons.check_circle,
                Colors.green, isBusy ? null : onApprove),

          if (canPrepare && _isPreparableStatus(status))
            _buildActionButton(
              context,
              status == 'approved' ? 'بدء التجهيز' : 'متابعة التعبئة',
              Icons.inventory_2,
              Colors.orange,
              isBusy ? null : onPrepare,
            ),

          if (canShip && _isShippableStatus(status))
            _buildActionButton(context, 'شحن', Icons.local_shipping,
                Colors.indigo, isBusy ? null : onShip),

          if (canApprove &&
              _isDeliverableStatus(
                  status)) // Using canApprove as proxy for delivery/manage permissions for now
            _buildActionButton(context, 'تسليم', Icons.delivery_dining,
                Colors.teal, isBusy ? null : onDeliver),

          if (canCancel && _isCancellableStatus(status, userRole))
            _buildActionButton(
                context,
                isBusy ? 'جارٍ التنفيذ...' : 'إلغاء',
                isBusy ? Icons.hourglass_top : Icons.cancel,
                theme.colorScheme.error,
                isBusy ? null : onCancel),

          // أزرار الزبون / التعديل
          if (canEdit)
            _buildActionButton(
                context,
                userRole == AppRole.warehouse ? 'تعديل التجهيز' : 'تعديل الطلب',
                Icons.edit,
                Colors.blue,
                isBusy ? null : onEdit),

          // تأكيد السعر للزبون (إذا كان له صلاحية معينة أو نستخدم canApprove للتبسيط)
          if (userRole == AppRole.customer && _isConfirmableStatus(status))
            _buildActionButton(context, 'موافق على السعر', Icons.check,
                Colors.green, isBusy ? null : onApprove),

          if (const {AppRole.admin, AppRole.manager, AppRole.accountant}
                  .contains(userRole) &&
              _isConfirmableStatus(status))
            _buildActionButton(
              context,
              'تأكيد السعر نيابةً عن الزبون',
              Icons.fact_check,
              Colors.deepPurple,
              isBusy ? null : onProxyCustomerConfirm,
            ),

          // زر الطباعة دائماً متاح إذا تم توفيره
          if (onPrint != null)
            _buildActionButton(context, 'طباعة / PDF', Icons.print,
                theme.colorScheme.onSurfaceVariant, isBusy ? null : onPrint),
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
    return ['pending', 'submitted', 'processing', 'customer_changed']
        .contains(status);
  }

  bool _isApprovableStatus(String status) {
    return status == 'customer_confirmed';
  }

  bool _isPreparableStatus(String status) {
    return ['approved', 'preparing'].contains(status);
  }

  bool _isShippableStatus(String status) {
    return ['prepared'].contains(status);
  }

  bool _isDeliverableStatus(String status) {
    return ['shipping'].contains(status);
  }

  bool _isCancellableStatus(String status, AppRole role) {
    final normalized = status.trim().toLowerCase();
    if (role == AppRole.customer) {
      return const {
        'pending',
        'submitted',
        'processing',
        'customer_changed',
        'priced',
      }.contains(normalized);
    }
    if (const {
      AppRole.admin,
      AppRole.manager,
      AppRole.accountant,
    }.contains(role)) {
      return !const {'cancelled', 'canceled', 'deleted'}.contains(normalized);
    }
    return false;
  }

  bool _isConfirmableStatus(String status) {
    return status == 'priced';
  }
}
