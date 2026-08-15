class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? company;
  final double? balance;

  Customer({
    required this.id,
    required this.name,
    this.phone,
    this.company,
    this.balance,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      phone: json['phone']?.toString(),
      company: json['company']?.toString(),
      balance: json['balance'] != null ? double.tryParse(json['balance'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'company': company,
      'balance': balance,
    };
  }
}
