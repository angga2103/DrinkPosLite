class CustomerModel {
  final String id;
  final String name;
  final String? phone;
  final int stamps;
  final int totalVisits;
  final String createdAt;

  CustomerModel({
    required this.id,
    required this.name,
    this.phone,
    this.stamps = 0,
    this.totalVisits = 0,
    required this.createdAt,
  });

  bool get hasReward => stamps >= 10;
  int get currentCycleStamps => stamps % 10;
  int get stampsRemaining => 10 - currentCycleStamps;

  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    return CustomerModel(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      stamps: (map['stamps'] as num? ?? 0).toInt(),
      totalVisits: (map['total_visits'] as num? ?? 0).toInt(),
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'stamps': stamps,
      'total_visits': totalVisits,
      'created_at': createdAt,
    };
  }

  CustomerModel copyWith({
    String? id,
    String? name,
    String? phone,
    int? stamps,
    int? totalVisits,
    String? createdAt,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      stamps: stamps ?? this.stamps,
      totalVisits: totalVisits ?? this.totalVisits,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
