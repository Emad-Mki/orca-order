import 'package:flutter/material.dart';

enum ProductAvailability {
  available,
  unavailable,
  uponRequest,
  preorder,
  comingSoon,
  unknown,
}

ProductAvailability productAvailabilityFrom({
  String? value,
}) {
  final normalized = (value ?? '')
      .trim()
      .toLowerCase()
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا');
  switch (normalized) {
    case 'available':
    case 'in_stock':
    case 'متوفر':
      return ProductAvailability.available;
    case 'unavailable':
    case 'out_of_stock':
    case 'غير متوفر':
      return ProductAvailability.unavailable;
    case 'upon_request':
    case 'on_request':
    case 'يمكن توفيره بناءً على الطلب':
    case 'متاح عند الطلب':
    case 'متوفر على الطلب':
    case 'متوفر عند الطلب':
      return ProductAvailability.uponRequest;
    case 'preorder':
    case 'pre_order':
    case 'حجز مسبق':
      return ProductAvailability.preorder;
    case 'coming_soon':
    case 'يتوفر قريبًا':
    case 'يتوفر قريبا':
    case 'قريبا':
      return ProductAvailability.comingSoon;
  }
  return ProductAvailability.unknown;
}

class ProductAvailabilityBadge extends StatelessWidget {
  final ProductAvailability availability;
  final bool compact;

  const ProductAvailabilityBadge({
    super.key,
    required this.availability,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final darkMode = theme.brightness == Brightness.dark;
    final (label, foreground) = switch (availability) {
      ProductAvailability.available => (
          'متوفر',
          darkMode ? const Color(0xFFA5D6A7) : const Color(0xFF2E7D32),
        ),
      ProductAvailability.unavailable => (
          'غير متوفر',
          darkMode ? const Color(0xFFEF9A9A) : const Color(0xFFC62828),
        ),
      ProductAvailability.uponRequest => (
          'متوفر على الطلب',
          darkMode ? const Color(0xFFFFCC80) : const Color(0xFFEF6C00),
        ),
      ProductAvailability.preorder => (
          'حجز مسبق',
          darkMode ? const Color(0xFFCE93D8) : const Color(0xFF7B1FA2),
        ),
      ProductAvailability.comingSoon => (
          'يتوفر قريبا',
          darkMode ? const Color(0xFF90CAF9) : const Color(0xFF1565C0),
        ),
      ProductAvailability.unknown => (
          'غير محددة',
          colors.onSurfaceVariant,
        ),
    };

    return Semantics(
      label: 'حالة المنتج: $label',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8,
          vertical: compact ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 7 : 8,
              height: compact ? 7 : 8,
              decoration: BoxDecoration(
                color: foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                softWrap: true,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
