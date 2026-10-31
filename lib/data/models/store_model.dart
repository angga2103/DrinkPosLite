class StoreModel {
  final String id;
  final String name;
  final String address;
  final String phone;
  final String receiptHeader;
  final String receiptFooter;
  final String currency;
  final String? logoPath;

  StoreModel({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.receiptHeader,
    required this.receiptFooter,
    this.currency = 'IDR',
    this.logoPath,
  });

  factory StoreModel.fromMap(Map<String, dynamic> map) {
    return StoreModel(
      id: map['id'] as String? ?? 'store_main',
      name: map['name'] as String? ?? 'Kedai Minuman',
      address: map['address'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      receiptHeader: map['receipt_header'] as String? ?? 'DRINKPOS LITE',
      receiptFooter: map['receipt_footer'] as String? ?? 'Terima Kasih!',
      currency: map['currency'] as String? ?? 'IDR',
      logoPath: map['logo_path'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'receipt_header': receiptHeader,
      'receipt_footer': receiptFooter,
      'currency': currency,
      'logo_path': logoPath,
    };
  }
}
