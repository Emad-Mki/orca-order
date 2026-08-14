import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ReportsScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  const ReportsScreen({super.key, required this.session});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Map<String, dynamic>? _reportData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService().post({
        'action': 'getReports',
        'username': widget.session['username'],
        'token': widget.session['token'],
      });
      if (mounted) {
        setState(() {
          _reportData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_reportData == null) return const Center(child: Text('تعذر تحميل التقارير'));

    final statusStats = _reportData!['statusStats'] as List? ?? [];
    final categorySales = _reportData!['categorySales'] as List? ?? [];

    return RefreshIndicator(
      onRefresh: _fetchReports,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('حالة الطلبات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 1.3,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: statusStats.map((s) {
                  final double val = (s['value'] as num).toDouble();
                  return PieChartSectionData(
                    color: _getStatusColor(s['name']),
                    value: val,
                    title: '${_getStatusTextAr(s['name'])}\n$val',
                    radius: 60,
                    titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('المبيعات حسب التصنيف',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 1.5,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: categorySales.isEmpty
                    ? 10
                    : categorySales
                            .map((c) => c['value'] as num)
                            .reduce((a, b) => a > b ? a : b)
                            .toDouble() *
                        1.2,
                barGroups: categorySales.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: (e.value['value'] as num).toDouble(),
                        color: Colors.blueAccent,
                        width: 20,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < categorySales.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              categorySales[index]['name'],
                              style: const TextStyle(fontSize: 10),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ...categorySales.map((c) => Card(
                child: ListTile(
                  title: Text(c['name']),
                  trailing: Text('\$${c['value']}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.green)),
                ),
              )),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return Colors.orange;
      case 'priced':
        return Colors.blue;
      case 'customer_confirmed':
        return Colors.purple;
      case 'approved':
        return Colors.green;
      case 'delivered':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  String _getStatusTextAr(String status) {
    switch (status.toLowerCase()) {
      case 'submitted': return 'جديدة';
      case 'priced': return 'مسعرة';
      case 'customer_confirmed': return 'مؤكدة من العميل';
      case 'approved': return 'معتمدة';
      case 'delivered': return 'تم التسليم';
      default: return status;
    }
  }
}

