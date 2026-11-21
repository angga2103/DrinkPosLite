import '../../core/database/app_database.dart';
import '../../core/utils/id_generator.dart';
import '../models/customer_model.dart';

class CustomerRepository {
  final AppDatabase _appDb;
  CustomerRepository([AppDatabase? appDb]) : _appDb = appDb ?? AppDatabase.instance;

  Future<List<CustomerModel>> getCustomers({String? query}) async {
    final db = await _appDb.database;
    String sql = 'SELECT * FROM customers WHERE 1=1';
    final List<dynamic> args = [];

    if (query != null && query.trim().isNotEmpty) {
      sql += ' AND (name LIKE ? OR phone LIKE ?)';
      final q = '%${query.trim()}%';
      args.addAll([q, q]);
    }
    sql += ' ORDER BY (id = "cust_default") DESC, name ASC';

    final res = await db.rawQuery(sql, args);
    return res.map((m) => CustomerModel.fromMap(m)).toList();
  }

  Future<CustomerModel?> getCustomerById(String id) async {
    final db = await _appDb.database;
    final res = await db.query('customers', where: 'id = ?', whereArgs: [id]);
    if (res.isEmpty) return null;
    return CustomerModel.fromMap(res.first);
  }

  Future<CustomerModel?> getCustomerByPhone(String phone) async {
    final cleanPhone = phone.trim();
    if (cleanPhone.isEmpty) return null;
    final db = await _appDb.database;
    final res = await db.query('customers', where: 'phone = ?', whereArgs: [cleanPhone]);
    if (res.isEmpty) return null;
    return CustomerModel.fromMap(res.first);
  }

  Future<CustomerModel> saveCustomer({
    String? id,
    required String name,
    String? phone,
    int stamps = 0,
    int totalVisits = 0,
  }) async {
    final db = await _appDb.database;
    final now = DateTime.now().toIso8601String();
    final effectiveId = id ?? IdGenerator.generateId(prefix: 'cust');

    final existing = await db.query('customers', where: 'id = ?', whereArgs: [effectiveId]);

    final customer = CustomerModel(
      id: effectiveId,
      name: name.trim(),
      phone: phone?.trim(),
      stamps: stamps,
      totalVisits: totalVisits,
      createdAt: now,
    );

    if (existing.isEmpty) {
      await db.insert('customers', customer.toMap());
    } else {
      await db.update(
        'customers',
        {
          'name': name.trim(),
          'phone': phone?.trim(),
          'stamps': stamps,
          'total_visits': totalVisits,
        },
        where: 'id = ?',
        whereArgs: [effectiveId],
      );
    }
    return customer;
  }

  /// Add stamps atomically and increment visits
  Future<CustomerModel?> addCustomerStamps(String customerId, int stampsToAdd) async {
    if (customerId == 'cust_default' || customerId.isEmpty) return null;
    final db = await _appDb.database;

    final rows = await db.query('customers', where: 'id = ?', whereArgs: [customerId]);
    if (rows.isEmpty) return null;

    final current = CustomerModel.fromMap(rows.first);
    final newStamps = current.stamps + stampsToAdd;
    final newVisits = current.totalVisits + 1;

    await db.update(
      'customers',
      {
        'stamps': newStamps,
        'total_visits': newVisits,
      },
      where: 'id = ?',
      whereArgs: [customerId],
    );

    return current.copyWith(stamps: newStamps, totalVisits: newVisits);
  }

  Future<void> deleteCustomer(String id) async {
    if (id == 'cust_default') return; // Cannot delete default customer
    final db = await _appDb.database;
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }
}
