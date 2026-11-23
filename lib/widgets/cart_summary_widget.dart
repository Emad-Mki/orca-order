import 'dart:math' show min;
import 'package:flutter/material.dart';
import '../models/order_item.dart';
import '../models/product.dart';
import '../utils/number_utils.dart';
import 'product_image_widget.dart';
import 'guided_tour.dart';
import '../services/guide_coordinator.dart';

/// Widget يعرض ملخص السلة مع إمكانية المراجعة والتأكيد
class CartSummaryWidget extends StatelessWidget {
  final List<OrderItem> cartItems;
  final VoidCallback? onReviewTap;
  final VoidCallback? onSubmitTap;
  final VoidCallback? onSaveDraftTap;
  final bool isSubmitting;

  const CartSummaryWidget({
    super.key,
    required this.cartItems,
    this.onReviewTap,
    this.onSubmitTap,
    this.onSaveDraftTap,
    this.isSubmitting = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // عرض السلة
          Row(
            children: [
              Icon(Icons.shopping_cart, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'السلة: ${cartItems.length} أصناف',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                  softWrap: true,
                ),
              ),
              if (cartItems.isNotEmpty && onReviewTap != null)
                TextButton(
                  onPressed: isSubmitting ? null : onReviewTap,
                  child: const Text('مراجعة'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // زر الإرسال
          Row(
            children: [
              if (onSaveDraftTap != null) ...[
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: isSubmitting ? null : onSaveDraftTap,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('حفظ مسودة'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed:
                        cartItems.isEmpty || isSubmitting ? null : onSubmitTap,
                    icon: const Icon(Icons.send),
                    label: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('تأكيد وإرسال'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// يظهر Dialog لمراجعة محتويات السلة
  static void showReviewDialog({
    required BuildContext context,
    required List<OrderItem> cartItems,
    required Future<void> Function() onSubmit,
    required ValueChanged<OrderItem> onRemoveItem,
    required void Function(OrderItem item, double quantity, String unit)
        onUpdateItem,
    bool isSubmitting = false,
    bool Function()? canEdit,
    String? guideAccountId,
  }) {
    var submitting = isSubmitting;
    final quantityControllers = <TextEditingController>[];
    final allControllers = <TextEditingController>[];
    final invalidControllers = <TextEditingController>{};
    for (final item in cartItems) {
      final controller = TextEditingController(text: '${item.quantity ?? 0}');
      quantityControllers.add(controller);
      allControllers.add(controller);
    }
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => GuidedTour(
        accountId: guideAccountId,
        name: 'review',
        targetCount: 3,
        ready:
            GuideCoordinator.ready && !submitting && (canEdit?.call() ?? true),
        canStart: () => !submitting && (canEdit?.call() ?? true),
        builder: (context, target) => StatefulBuilder(
          builder: (context, setDialogState) => PopScope(
            canPop: !submitting,
            child: AlertDialog(
              title: const Text('مراجعة الطلب قبل الإرسال'),
              content: SizedBox(
                width: min(560.0, MediaQuery.sizeOf(context).width - 48)
                    .toDouble(),
                height: min(560.0, MediaQuery.sizeOf(context).height * 0.65)
                    .toDouble(),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: cartItems.length,
                        itemBuilder: (context, index) {
                          final item = cartItems[index];
                          final units =
                              item.product?.availableUnits ?? [item.unit];
                          final unit = item.selectedUnit ?? item.unit;
                          final quantity = item.quantity ?? 0;
                          final controller = quantityControllers[index];
                          final editable =
                              !submitting && (canEdit?.call() ?? true);
                          Widget guideFirst(Widget child) => index == 0
                              ? target(
                                  0,
                                  'عدّل الكمية والوحدة هنا قبل إرسال الطلب.',
                                  child)
                              : child;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildProductImage(item.product),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          item.product?.name ?? item.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                  fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'حذف الصنف',
                                        icon: Icon(Icons.delete_outline,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error),
                                        onPressed: !editable
                                            ? null
                                            : () {
                                                if (!cartItems.contains(item)) {
                                                  return;
                                                }
                                                onRemoveItem(item);
                                                quantityControllers
                                                    .removeAt(index);
                                                invalidControllers
                                                    .remove(controller);
                                                setDialogState(() {});
                                              },
                                      ),
                                    ],
                                  ),
                                  if (item.code.isNotEmpty)
                                    Text('رمز المنتج: ${item.code}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                  if (item.offer != null)
                                    Text(
                                      'عرض للوحدة ${item.offer!.unit} • الحد الأدنى ${item.offer!.minimum} ${item.offer!.unit} • السعر قابل للتحقق عند الإرسال',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  if (item.offerBelowMinimum)
                                    Text(
                                      item.defaultPrice == null
                                          ? 'الكمية أقل من الحد الأدنى؛ السعر العادي غير محفوظ وسيُتحقق منه قبل الإرسال.'
                                          : 'الكمية أقل من الحد الأدنى؛ السعر العادي التقديري ${formatMoneyShort(item.defaultPrice!, currency: item.currency)} لكل $unit بدلاً من سعر العرض. سيُحدّث ويُؤكّد قبل الإرسال.',
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error),
                                    ),
                                  const SizedBox(height: 8),
                                  guideFirst(Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      IconButton.filledTonal(
                                        tooltip: 'إنقاص الكمية',
                                        onPressed: !editable || quantity <= 1
                                            ? null
                                            : () {
                                                if (!cartItems.contains(item)) {
                                                  return;
                                                }
                                                final next = ((item.quantity ??
                                                            0) -
                                                        1)
                                                    .clamp(0.0, double.infinity)
                                                    .toDouble();
                                                if (next <= 0) return;
                                                onUpdateItem(item, next, unit);
                                                controller.text =
                                                    next.toString();
                                                invalidControllers
                                                    .remove(controller);
                                                setDialogState(() {});
                                              },
                                        icon:
                                            const Icon(Icons.remove, size: 18),
                                      ),
                                      SizedBox(
                                        width: 72,
                                        child: TextField(
                                          controller: controller,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          textAlign: TextAlign.center,
                                          enabled: editable,
                                          onChanged: (value) {
                                            final next = double.tryParse(value);
                                            if (next == null ||
                                                !next.isFinite ||
                                                next <= 0) {
                                              setDialogState(() =>
                                                  invalidControllers
                                                      .add(controller));
                                              return;
                                            }
                                            invalidControllers
                                                .remove(controller);
                                            onUpdateItem(item, next, unit);
                                            setDialogState(() {});
                                          },
                                          onSubmitted: (_) {
                                            if (invalidControllers
                                                .remove(controller)) {
                                              controller.text =
                                                  (item.quantity ?? 0)
                                                      .toString();
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                    content: Text(
                                                        'أدخل كمية صحيحة أكبر من صفر')),
                                              );
                                              setDialogState(() {});
                                            }
                                          },
                                        ),
                                      ),
                                      IconButton.filledTonal(
                                        tooltip: 'زيادة الكمية',
                                        onPressed: !editable
                                            ? null
                                            : () {
                                                if (!cartItems.contains(item)) {
                                                  return;
                                                }
                                                final next =
                                                    (item.quantity ?? 0) + 1;
                                                onUpdateItem(item, next, unit);
                                                controller.text =
                                                    next.toString();
                                                invalidControllers
                                                    .remove(controller);
                                                setDialogState(() {});
                                              },
                                        icon: const Icon(Icons.add, size: 18),
                                      ),
                                      if (units.length > 1 &&
                                          item.offer == null)
                                        DropdownButton<String>(
                                          value: units.contains(unit)
                                              ? unit
                                              : units.first,
                                          items: units
                                              .map((value) => DropdownMenuItem(
                                                    value: value,
                                                    child: Text(value),
                                                  ))
                                              .toList(),
                                          onChanged: !editable
                                              ? null
                                              : (value) {
                                                  if (value != null &&
                                                      cartItems
                                                          .contains(item)) {
                                                    onUpdateItem(
                                                        item,
                                                        item.quantity ?? 0,
                                                        value);
                                                    setDialogState(() {});
                                                  }
                                                },
                                        )
                                      else
                                        Text('الوحدة: $unit'),
                                    ],
                                  )),
                                  if (item.note?.trim().isNotEmpty == true)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text('ملاحظة: ${item.note}',
                                          softWrap: true),
                                    ),
                                  if (!item.hasConfiguredUnitPrice ||
                                      !item.hasConfiguredUnitConversion)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        !item.hasConfiguredUnitPrice
                                            ? 'سعر هذه الوحدة غير مضبوط'
                                            : 'معامل تحويل الوحدة غير مضبوط',
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                          item.hasConfiguredUnitPrice
                                              ? 'سعر الوحدة: ${formatMoneyShort(item.displayPrice, currency: item.currency)}'
                                              : 'سعر هذه الوحدة غير مضبوط',
                                          style: TextStyle(
                                            color: item.hasConfiguredUnitPrice
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .error,
                                          )),
                                      Text(
                                        formatMoneyShort(item.total,
                                            currency: item.currency),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    target(
                        1,
                        'راجع الإجمالي قبل التأكيد.',
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Text(
                            'الإجمالي: ${formatMoneyShort(cartItems.fold<double>(0, (sum, item) => sum + item.total), currency: cartItems.isEmpty ? 'USD' : cartItems.first.currency)}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        )),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(context),
                  child: const Text('إغلاق'),
                ),
                target(
                    2,
                    'يُرسل الطلب فقط عند الضغط على التأكيد بعد انتهاء الشرح.',
                    FilledButton(
                      onPressed: submitting ||
                              cartItems.isEmpty ||
                              invalidControllers.isNotEmpty ||
                              cartItems.any((item) =>
                                  (!item.hasConfiguredUnitPrice &&
                                      item.offer == null) ||
                                  !item.hasConfiguredUnitConversion)
                          ? null
                          : () async {
                              setDialogState(() => submitting = true);
                              await onSubmit();
                              if (context.mounted) {
                                setDialogState(() => submitting = false);
                              }
                            },
                      child: submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('تأكيد وإرسال'),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
    Navigator.of(context, rootNavigator: true).push(route);
    route.completed.then((_) {
      for (final controller in allControllers) {
        controller.dispose();
      }
    });
  }

  static Widget _buildProductImage(Product? product) {
    return ProductImageWidget(
      imageUrl: product?.imageUrl,
      width: 60,
      height: 60,
      borderRadius: BorderRadius.circular(8),
    );
  }
}
