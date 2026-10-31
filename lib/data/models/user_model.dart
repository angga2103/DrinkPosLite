class UserModel {
  final String id;
  final String name;
  final String role; // OWNER, MANAGER, CASHIER
  final String pinHash;
  final bool isActive;
  final bool isLocked;
  final int failedAttempts;
  final String? joinDate;
  final double monthlySalary;
  final String shiftStartTime;
  final String shiftEndTime;
  final String shiftName;
  final List<String> permissions;

  UserModel({
    required this.id,
    required this.name,
    required this.role,
    required this.pinHash,
    this.isActive = true,
    this.isLocked = false,
    this.failedAttempts = 0,
    this.joinDate,
    this.monthlySalary = 0.0,
    this.shiftStartTime = '08:00',
    this.shiftEndTime = '16:00',
    this.shiftName = 'Shift Pagi',
    this.permissions = const [],
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? role,
    String? pinHash,
    bool? isActive,
    bool? isLocked,
    int? failedAttempts,
    String? joinDate,
    double? monthlySalary,
    String? shiftStartTime,
    String? shiftEndTime,
    String? shiftName,
    List<String>? permissions,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      pinHash: pinHash ?? this.pinHash,
      isActive: isActive ?? this.isActive,
      isLocked: isLocked ?? this.isLocked,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      joinDate: joinDate ?? this.joinDate,
      monthlySalary: monthlySalary ?? this.monthlySalary,
      shiftStartTime: shiftStartTime ?? this.shiftStartTime,
      shiftEndTime: shiftEndTime ?? this.shiftEndTime,
      shiftName: shiftName ?? this.shiftName,
      permissions: permissions ?? this.permissions,
    );
  }

  bool get isOwner => role == 'OWNER';
  bool get isManager => role == 'MANAGER';
  bool get isCashier => role == 'CASHIER';

  static const Map<String, String> availableMenuLabels = {
    'pos': 'Mulai Jualan (POS Kasir)',
    'products': 'Produk & Menu Minuman',
    'inventory': 'Stok Bahan & Resep HPP',
    'purchases': 'Pembelian Bahan Baku',
    'expenses': 'Pengeluaran Toko',
    'shifts': 'Shift & Buka/Tutup Kas',
    'attendance': 'Absensi Pegawai',
    'reports': 'Laporan Penjualan',
    'employees': 'Pengelolaan Pegawai',
    'printer': 'Pengaturan Printer Bluetooth',
    'settings': 'Pengaturan Toko & Logo',
    'backup': 'Backup & Restore Database',
  };

  /// Check whether user can access a given menu
  bool canAccess(String menuKey) {
    if (menuKey == 'printer') return true; // Accessible for all roles (Cashier, Manager, Owner)
    if (isOwner) return true;
    if (permissions.isNotEmpty) {
      return permissions.contains(menuKey);
    }
    // Fallback default permissions based on role
    if (isManager) {
      return ['pos', 'products', 'inventory', 'purchases', 'expenses', 'shifts', 'attendance', 'reports', 'printer'].contains(menuKey);
    }
    return ['pos', 'attendance', 'printer'].contains(menuKey);
  }

  bool get canManageSettings => isOwner || canAccess('settings');
  bool get canManageStoreProfile => isOwner || isManager;
  bool get canManageEmployees => isOwner || canAccess('employees');
  bool get canManageHpp => isOwner || canAccess('inventory');
  bool get canRestoreBackup => isOwner || canAccess('backup');
  bool get canCancelTransaction => isOwner || isManager || canAccess('pos');
  bool get canManageInventory => isOwner || isManager || canAccess('inventory');
  bool get canManagePurchases => isOwner || isManager || canAccess('purchases');
  bool get canManageExpenses => isOwner || isManager || canAccess('expenses');
  bool get canViewReports => isOwner || isManager || canAccess('reports');

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final permStr = map['permissions'] as String?;
    final perms = permStr != null && permStr.isNotEmpty
        ? permStr.split(',').where((s) => s.trim().isNotEmpty).toList()
        : <String>[];

    return UserModel(
      id: map['id'] as String,
      name: map['name'] as String,
      role: map['role'] as String,
      pinHash: map['pin_hash'] as String,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      isLocked: (map['is_locked'] as int? ?? 0) == 1,
      failedAttempts: map['failed_attempts'] as int? ?? 0,
      joinDate: map['join_date'] as String?,
      monthlySalary: (map['monthly_salary'] as num? ?? 0.0).toDouble(),
      shiftStartTime: map['shift_start_time'] as String? ?? '08:00',
      shiftEndTime: map['shift_end_time'] as String? ?? '16:00',
      shiftName: map['shift_name'] as String? ?? 'Shift Pagi',
      permissions: perms,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'pin_hash': pinHash,
      'is_active': isActive ? 1 : 0,
      'is_locked': isLocked ? 1 : 0,
      'failed_attempts': failedAttempts,
      'join_date': joinDate,
      'monthly_salary': monthlySalary,
      'shift_start_time': shiftStartTime,
      'shift_end_time': shiftEndTime,
      'shift_name': shiftName,
      'permissions': permissions.join(','),
    };
  }
}
