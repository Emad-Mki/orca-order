/// نموذج معلومات الرصيد
class BalanceInfo {
  final double previousBalance;
  final double currentInvoiceTotal;
  final double totalPaid;
  final double openingBalance;
  final double newBalance;
  final String currency;

  BalanceInfo({
    required this.previousBalance,
    required this.currentInvoiceTotal,
    required this.totalPaid,
    required this.openingBalance,
    required this.newBalance,
    required this.currency,
  });

  factory BalanceInfo.fromJson(Map<String, dynamic> json) {
    double parseAmount(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      
      String str = value.toString().trim();
      if (str.isEmpty) return 0.0;
      
      str = str.replaceAll(',', '')
               .replaceAll('\$', '')
               .replaceAll('USD', '')
               .replaceAll('SYP', '')
               .replaceAll(' ', '');
      
      return double.tryParse(str) ?? 0.0;
    }

    return BalanceInfo(
      previousBalance: parseAmount(json['previous_balance']),
      currentInvoiceTotal: parseAmount(json['current_invoice_total']),
      totalPaid: parseAmount(json['total_paid']),
      openingBalance: parseAmount(json['opening_balance']),
      newBalance: parseAmount(json['new_balance']),
      currency: json['currency'] ?? 'USD',
    );
  }

  Map<String, dynamic> toJson() => {
    'previous_balance': previousBalance,
    'current_invoice_total': currentInvoiceTotal,
    'total_paid': totalPaid,
    'opening_balance': openingBalance,
    'new_balance': newBalance,
    'currency': currency,
  };
}
