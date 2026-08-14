import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../app_config.dart';

/// شاشة سجل التدقيق (Audit Log)
class AuditLogScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  const AuditLogScreen({super.key, required this.session});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  List<dynamic> _logs = [];
  bool _isLoading = true;
  String _filterUser = 'all';
  String _filterEntity = 'all';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(AppConfig.baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'getAuditLogs',
          'username': widget.session['username'],
          'token': widget.session['token'],
        }),
      );
      final data = json.decode(response.body);
      if (data['success'] == true) {
        setState(() {
          _logs = data['logs'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'فشل تحميل السجل')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: \$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل التدقيق'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                return ListTile(
                  leading: Icon(
                    _getIconForAction(log['action']),
                    color: _getColorForAction(log['action']),
                  ),
                  title: Text(log['description'] ?? ''),
                  subtitle: Text(
                    '\${log['user']} - \${_formatDate(log['timestamp'])}',
                  ),
                  isThreeLine: true,
                );
              },
            ),
    );
  }

  IconData _getIconForAction(String? action) {
    switch (action) {
      case 'create':
        return Icons.add_circle;
      case 'update':
        return Icons.edit;
      case 'delete':
        return Icons.delete;
      default:
        return Icons.info;
    }
  }

  Color _getColorForAction(String? action) {
    switch (action) {
      case 'create':
        return Colors.green;
      case 'update':
        return Colors.orange;
      case 'delete':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _formatDate(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp);
      return '\${dt.day}/\${dt.month}/\${dt.year} \${dt.hour}:\${dt.minute}';
    } catch (e) {
      return timestamp;
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تصفية السجل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<String>(
              value: _filterUser,
              items: ['all', 'user1', 'user2']
                  .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                  .toList(),
              onChanged: (v) => setState(() => _filterUser = v!),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}
