import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// Durable, account- and role-scoped snapshots returned by sales_invoice_list.
class SalesInvoiceStore {
  SalesInvoiceStore({
    required this.environment,
    required this.userId,
    required this.role,
    this.directory,
  }) {
    if (environment.trim().isEmpty ||
        userId.trim().isEmpty ||
        !{'admin', 'accountant', 'manager', 'salesperson'}.contains(role)) {
      throw ArgumentError('Invalid sales invoice storage scope');
    }
  }

  final String environment;
  final String userId;
  final String role;

  /// Overrides the app-support directory for tests.
  final Directory? directory;

  static final Map<String, Future<void>> _writes = {};

  String _date(Map<String, dynamic> row) {
    final date = row['invoice_date']?.toString() ?? '';
    return date.isNotEmpty ? date : (row['created_at']?.toString() ?? '');
  }

  Future<File> _file() async {
    final root = directory ?? await getApplicationSupportDirectory();
    final hash = sha256.convert(utf8.encode(jsonEncode([
      environment,
      userId,
      role,
    ])));
    return File(
        '${root.path}${Platform.pathSeparator}sales_invoices_$hash.json');
  }

  bool _valid(Map<String, dynamic> row) {
    bool number(String key) {
      final value = row[key];
      final parsed = value is num ? value : num.tryParse('$value');
      return parsed != null && parsed.isFinite;
    }

    return (row['invoice_id']?.toString().trim().isNotEmpty ?? false) &&
        DateTime.tryParse(_date(row)) != null &&
        row['items'] is List &&
        (row['items'] as List).every((item) => item is Map) &&
        row['payments'] is List &&
        (row['payments'] as List).every((payment) => payment is Map) &&
        [
          'subtotal',
          'discount',
          'net_total',
          'total_paid_usd',
          'balance_due_usd'
        ].every(number) &&
        (role != 'salesperson' || '${row['seller_id']}' == userId);
  }

  Future<List<Map<String, dynamic>>> _read(File file) async {
    if (!await file.exists()) return [];
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map ||
        decoded['version'] != 1 ||
        decoded['invoices'] is! List) {
      throw const FormatException('Invalid invoice cache');
    }
    final rows = (decoded['invoices'] as List).map((value) {
      if (value is! Map) {
        throw const FormatException('Invalid invoice snapshot');
      }
      final row = Map<String, dynamic>.from(value);
      if (!_valid(row)) throw const FormatException('Invalid invoice snapshot');
      return row;
    }).toList();
    return rows;
  }

  /// Merges a filtered response without deleting snapshots outside that response.
  Future<void> merge(List<Map<String, dynamic>> invoices) async {
    final file = await _file();
    final key = file.absolute.path;
    final previous = _writes[key] ?? Future<void>.value();
    final operation = previous.then((_) async {
      if (!invoices.every(_valid)) {
        throw const FormatException('Invalid invoice snapshot');
      }
      final rows = {
        for (final row in await _read(file)) '${row['invoice_id']}': row
      };
      for (final row in invoices) {
        rows['${row['invoice_id']}'] = row;
      }
      final encoded =
          jsonEncode({'version': 1, 'invoices': rows.values.toList()});
      await file.parent.create(recursive: true);
      final temp = File('$key.${DateTime.now().microsecondsSinceEpoch}.tmp');
      try {
        await temp.writeAsString(encoded, flush: true);
        await temp.rename(file.path);
      } finally {
        if (await temp.exists()) await temp.delete();
      }
    });
    final settled =
        operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _writes[key] = settled;
    try {
      await operation;
    } finally {
      if (identical(_writes[key], settled)) _writes.remove(key);
    }
  }

  /// Applies the server list's filters to previously seen snapshots only.
  Future<List<Map<String, dynamic>>> list({
    String query = '',
    DateTime? fromDate,
    DateTime? toDate,
    String? status,
    String? financialStatus,
    String? paymentMethod,
    String? sellerId,
    String? customerId,
  }) async {
    final file = await _file();
    await (_writes[file.absolute.path] ?? Future<void>.value());
    final needle = query.trim().toLowerCase();
    final rows = (await _read(file)).where((row) {
      final date = DateTime.parse(_date(row));
      final searchable = [
        row['invoice_number'],
        row['invoice_id'],
        row['customer_name'],
        row['buyer_name'],
        row['buyer_phone'],
        row['payment_method'],
        row['status'],
        row['seller_name'],
      ].map((value) => value?.toString() ?? '').join(' ').toLowerCase();
      return (fromDate == null || !date.isBefore(fromDate)) &&
          (toDate == null || !date.isAfter(toDate)) &&
          (status == null || '${row['status']}' == status) &&
          (financialStatus == null ||
              '${row['financial_status']}' == financialStatus) &&
          (sellerId == null || '${row['seller_id']}' == sellerId) &&
          (customerId == null || '${row['customer_id']}' == customerId) &&
          (paymentMethod == null ||
              (row['payments'] as List).any((payment) {
                final method = payment['payment_method']?.toString() ?? '';
                return (method.isNotEmpty
                        ? method
                        : (payment['method']?.toString() ?? '')) ==
                    paymentMethod;
              })) &&
          (needle.isEmpty || searchable.contains(needle));
    }).toList();
    rows.sort(
        (a, b) => DateTime.parse(_date(b)).compareTo(DateTime.parse(_date(a))));
    return rows;
  }
}
