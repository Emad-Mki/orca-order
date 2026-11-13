import 'package:flutter/material.dart';

/// ويدجت سجل تعديلات الطلب
class OrderHistoryWidget extends StatelessWidget {
  final List<dynamic> history;

  const OrderHistoryWidget({
    super.key,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const SizedBox.shrink();
    }
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'سجل التعديلات',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Divider(),
            ...history.map((entry) => _buildHistoryTile(entry, muted)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTile(dynamic entry, Color muted) {
    final date = entry['date'] != null ? _formatDate(entry['date']) : '';
    final user = entry['username'] ?? 'مستخدم';
    final action = entry['action'] ?? 'تعديل';
    final details = entry['details'] ?? '';

    return ListTile(
      leading: const Icon(Icons.history, size: 20),
      title: Text(
        action,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: details.isNotEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (details.isNotEmpty) Text(details),
                Text(
                  '$user • $date',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ],
            )
          : Text(
              '$user • $date',
              style: TextStyle(fontSize: 11, color: muted),
            ),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    if (date is DateTime) {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return date.toString();
  }
}
