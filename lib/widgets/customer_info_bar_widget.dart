import 'package:flutter/material.dart';

/// شريط معلومات الزبون يظهر في أعلى الشاشات
class CustomerInfoBarWidget extends StatelessWidget {
  final String? customerName;
  final IconData icon;
  final Color? backgroundColor;
  final TextStyle? textStyle;

  const CustomerInfoBarWidget({
    super.key,
    this.customerName,
    this.icon = Icons.person,
    this.backgroundColor,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: backgroundColor ?? theme.colorScheme.primaryContainer,
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.onPrimaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'الزبون: ${customerName ?? "جاري التحميل..."}',
              style: textStyle ??
                  TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
