import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/drafts_provider.dart';
import '../models/order_draft.dart';
import 'new_order_screen.dart';
import 'sales_invoice_pdf_screen.dart';

class DraftsListScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  const DraftsListScreen({super.key, required this.session});

  @override
  State<DraftsListScreen> createState() => _DraftsListScreenState();
}

class _DraftsListScreenState extends State<DraftsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DraftsProvider>().loadDrafts();
    });
  }

  void _renameDraft(OrderDraft draft) {
    final ctrl = TextEditingController(text: draft.customTitle ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعادة تسمية المسودة'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'اسم المسودة'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final newDraft = OrderDraft(
                id: draft.id,
                customerId: draft.customerId,
                customerName: draft.customerName,
                updatedAt: DateTime.now(),
                items: draft.items,
                note: draft.note,
                currency: draft.currency,
                customTitle: ctrl.text,
                clientRequestId: draft.clientRequestId,
              );
              context.read<DraftsProvider>().saveDraft(newDraft);
              Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(OrderDraft draft) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المسودة'),
        content: const Text('هل أنت متأكد من حذف هذه المسودة نهائياً؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              context.read<DraftsProvider>().deleteDraft(draft.id!);
              Navigator.pop(context);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(
        title: const Text('مسوداتي'),
      ),
      body: Consumer<DraftsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.drafts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.note_add_outlined, size: 64, color: muted),
                  const SizedBox(height: 16),
                  Text('لا توجد مسودات حالياً', style: TextStyle(color: muted)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: provider.drafts.length,
            itemBuilder: (context, index) {
              final draft = provider.drafts[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                      draft.customTitle ??
                          (draft.customerName.isEmpty
                              ? 'طلب بدون زبون'
                              : draft.customerName),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'عدد البنود: ${draft.items.length} | المجموع: ${draft.total.toStringAsFixed(2)} ${draft.currency}'),
                      Text(
                          'آخر تعديل: ${DateFormat('yyyy-MM-dd HH:mm').format(draft.updatedAt)}',
                          style: const TextStyle(fontSize: 12)),
                      if (draft.clientRequestId != null)
                        const Text(
                            'إرسال غير مؤكد؛ افتح المسودة لإعادة المحاولة'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'معاينة مسودة PDF',
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        onPressed: () {
                          final snapshot = <String, dynamic>{
                            'invoice_id': 'order-draft-${draft.id}',
                            'kind': 'order_draft',
                            'is_unsynced': true,
                            'sync_uncertain': draft.clientRequestId != null,
                            'invoice_date': draft.updatedAt.toIso8601String(),
                            'customer_name': draft.customerName,
                            'currency': draft.currency,
                            'subtotal': draft.total,
                            'net_total': draft.total,
                            'notes': draft.note,
                            'items': draft.items
                                .map((item) => {
                                      'code': item.productCode,
                                      'name_snapshot': item.productName,
                                      'quantity': item.quantity,
                                      'unit': item.unit,
                                      'unit_price': item.price,
                                      'line_total': item.quantity * item.price,
                                      'note': item.note,
                                    })
                                .toList(),
                          };
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  SalesInvoicePdfScreen(invoice: snapshot),
                            ),
                          );
                        },
                      ),
                      IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: draft.clientRequestId == null
                              ? () => _renameDraft(draft)
                              : null),
                      IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: draft.clientRequestId == null
                              ? () => _confirmDelete(draft)
                              : null),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NewOrderScreen(
                          session: widget.session,
                          draft: draft,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
