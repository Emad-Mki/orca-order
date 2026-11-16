import 'package:flutter/material.dart';

class SalesStockTransferScreen extends StatelessWidget {
  const SalesStockTransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('مخزون المندوبين')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 52,
                color: colors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'يستخدم جميع المندوبين المخزون العام الموحد.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'أرصدة التخصيص السابقة محفوظة كسجل تاريخي ولا تضاف إلى رصيد المخزون العام.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
