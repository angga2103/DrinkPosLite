import '../../core/database/app_database.dart';
import '../../core/security/audit_logger.dart';
import '../../core/utils/id_generator.dart';
import '../models/purchase_model.dart';

class PurchaseRepository {
  final AppDatabase _appDb;
  PurchaseRepository([AppDatabase? appDb]) : _appDb = appDb ?? AppDatabase.instance;

  Future<List<PurchaseModel>> getPurchases({int limit = 50}) async {
    final db = await _appDb.database;
    final res = await db.query('purchases', orderBy: 'purchase_date DESC, created_at DESC', limit: limit);
    final List<PurchaseModel> list = [];

    for (final row in res) {
      final pId = row['id'] as String;
      final itemRows = await db.rawQuery('''
        SELECT pi.*, i.name as ingredient_name
        FROM purchase_items pi
        JOIN ingredients i ON pi.ingredient_id = i.id
        WHERE pi.purchase_id = ?
      ''', [pId]);
      final items = itemRows.map((m) => PurchaseItemModel.fromMap(m)).toList();
      list.add(PurchaseModel.fromMap(row, items: items));
    }
    return list;
  }

  Future<void> savePurchase({
    required PurchaseModel purchase,
    required List<PurchaseItemModel> items,
    String? currentShiftId,
    String? userId,
    String? userName,
  }) async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();

      // 1. Insert into purchases table
      await txn.insert('purchases', {
        ...purchase.toMap(),
        'created_at': now,
      });

      // 2. Process each purchased item
      for (final item in items) {
        await txn.insert('purchase_items', item.toMap());

        // Get current ingredient info
        final ingRows = await txn.query('ingredients', where: 'id = ?', whereArgs: [item.ingredientId]);
        if (ingRows.isNotEmpty) {
          final currentStock = (ingRows.first['current_stock'] as num).toDouble();
          final newStock = currentStock + item.quantity;

          // Update stock and cost per unit / last buy price
          await txn.update(
            'ingredients',
            {
              'current_stock': newStock,
              'cost_per_unit': item.unitPrice,
              'last_buy_price': item.unitPrice,
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [item.ingredientId],
          );

          // Create stock batch
          final batchId = IdGenerator.generateId(prefix: 'bat');
          await txn.insert('stock_batches', {
            'id': batchId,
            'ingredient_id': item.ingredientId,
            'batch_number': item.batchNumber ?? 'BATCH-${purchase.purchaseNumber}',
            'initial_quantity': item.quantity,
            'remaining_quantity': item.quantity,
            'unit_cost': item.unitPrice,
            'expiry_date': item.expiryDate,
            'received_date': purchase.purchaseDate,
            'is_active': 1,
          });

          // Create stock movement
          await txn.insert('stock_movements', {
            'id': IdGenerator.generateId(prefix: 'sm'),
            'ingredient_id': item.ingredientId,
            'batch_id': batchId,
            'movement_type': 'PURCHASE',
            'quantity_change': item.quantity,
            'quantity_before': currentStock,
            'quantity_after': newStock,
            'reference_id': purchase.purchaseNumber,
            'reason': 'Pembelian dari ${purchase.supplierName ?? "Supplier"}',
            'user_id': userId,
            'created_at': now,
          });
        }
      }

      // 3. Create expense record
      final expCatRows = await txn.query(
        'expense_categories',
        where: 'name LIKE ? OR id = ?',
        whereArgs: ['%Bahan%', 'expcat_ing'],
        limit: 1,
      );
      final catId = expCatRows.isNotEmpty ? expCatRows.first['id'] as String : 'expcat_ing';
      final catName = expCatRows.isNotEmpty ? expCatRows.first['name'] as String : 'Pembelian Bahan Baku';

      await txn.insert('expenses', {
        'id': IdGenerator.generateId(prefix: 'exp'),
        'shift_id': currentShiftId,
        'category_id': catId,
        'category_name': catName,
        'amount': purchase.totalAmount,
        'payment_method': purchase.paymentMethod,
        'description': 'Pembelian bahan: ${purchase.purchaseNumber} (${purchase.supplierName ?? "-"})',
        'date': purchase.purchaseDate,
        'created_by': userName ?? 'User',
        'created_at': now,
      });

      // If paid by cash and there is an active shift, deduct shift's total_cash_expenses
      if (purchase.paymentMethod == 'TUNAI' && currentShiftId != null) {
        await txn.rawUpdate('''
          UPDATE shifts 
          SET total_cash_expenses = total_cash_expenses + ?,
              expected_cash = initial_cash + total_cash_sales - (total_cash_expenses + ?)
          WHERE id = ? AND status = 'OPEN'
        ''', [purchase.totalAmount, purchase.totalAmount, currentShiftId]);
      }

      await AuditLogger.log(
        action: 'PURCHASE_CREATE',
        entityType: 'PURCHASE',
        entityId: purchase.id,
        userId: userId,
        userName: userName,
        reason: 'Pembelian bahan ${purchase.purchaseNumber} senilai ${purchase.totalAmount}',
        db: txn,
      );
    });
  }
}
