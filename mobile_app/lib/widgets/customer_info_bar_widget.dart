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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: backgroundColor ?? (isDark ? Colors.blueGrey[900] : Colors.blue[50]),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'الزبون: ${customerName ?? "جاري التحميل..."}',
              style: textStyle ??
                  const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
