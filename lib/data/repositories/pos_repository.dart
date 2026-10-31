import 'dart:convert';
import '../../core/constants/app_constants.dart';
import '../../core/database/app_database.dart';
import '../../core/security/audit_logger.dart';
import '../../core/utils/id_generator.dart';
import '../models/promotion_model.dart';
import '../models/transaction_model.dart';

class PosRepository {
  final AppDatabase _appDb;
  PosRepository([AppDatabase? appDb]) : _appDb = appDb ?? AppDatabase.instance;

  // Active Promotions
  Future<List<PromotionModel>> getActivePromotions() async {
    final db = await _appDb.database;
    final res = await db.query('promotions', where: 'is_active = 1', orderBy: 'discount_value DESC');
    return res.map((m) => PromotionModel.fromMap(m)).toList();
  }

  // Create Transaction (Atomic)
  Future<TransactionModel> createTransaction({
    required String cashierId,
    required String cashierName,
    String? shiftId,
    String? storeId,
    required List<TransactionItemModel> items,
    required double totalAmount,
    double discountAmount = 0.0,
    required double finalAmount,
    required String paymentMethod, // 'TUNAI', 'QRIS', 'SPLIT'
    double cashReceived = 0.0,
    double qrisAmount = 0.0,
    double changeAmount = 0.0,
    String? notes,
  }) async {
    final db = await _appDb.database;
    final now = DateTime.now().toIso8601String();
    final trxId = IdGenerator.generateId(prefix: 'trx');
    final trxNumber = IdGenerator.generateTransactionNumber();

    // Strict Shift Enforcement: Shift must be open and active
    String effectiveShiftId;
    if (shiftId == null || shiftId.trim().isEmpty) {
      final openShifts = await db.rawQuery(
        "SELECT id FROM shifts WHERE status = 'OPEN' ORDER BY start_time DESC LIMIT 1",
      );
      if (openShifts.isEmpty) {
        throw Exception('Penjualan ditolak: Shift kasir belum dibuka! Silakan buka shift terlebih dahulu.');
      }
      effectiveShiftId = openShifts.first['id'] as String;
    } else {
      final activeShift = await db.query(
        'shifts',
        where: 'id = ? AND status = ?',
        whereArgs: [shiftId, 'OPEN'],
      );
      if (activeShift.isEmpty) {
        throw Exception('Penjualan ditolak: Shift $shiftId sudah ditutup atau tidak aktif!');
      }
      effectiveShiftId = shiftId;
    }

    TransactionModel? completedTrx;

    await db.transaction((txn) async {
      double calculatedTotalCogs = 0.0;
      final List<TransactionItemModel> processedItems = [];

      // 1. Process each item and its recipe / HPP snapshot
      for (final item in items) {
        final itemId = IdGenerator.generateId(prefix: 'ti');

        // Look up active recipe for this product & variant
        String recipeSql = 'SELECT * FROM recipes WHERE product_id = ?';
        final List<dynamic> recipeArgs = [item.productId];
        if (item.variantId != null && item.variantId!.isNotEmpty) {
          recipeSql += ' AND variant_id = ?';
          recipeArgs.add(item.variantId);
        }
        final recipeRows = await txn.rawQuery(recipeSql, recipeArgs);

        double itemUnitCogs = 0.0;
        final List<Map<String, dynamic>> recipeSnapshotList = [];

        if (recipeRows.isNotEmpty) {
          final recipeId = recipeRows.first['id'] as String;
          final recipeItemRows = await txn.rawQuery('''
            SELECT ri.ingredient_id, ri.amount_required, i.name as ingredient_name, i.unit, i.cost_per_unit, i.current_stock
            FROM recipe_items ri
            JOIN ingredients i ON ri.ingredient_id = i.id
            WHERE ri.recipe_id = ?
          ''', [recipeId]);

          for (final rItem in recipeItemRows) {
            final ingId = rItem['ingredient_id'] as String;
            final amountPerCup = (rItem['amount_required'] as num).toDouble();
            final unitCost = (rItem['cost_per_unit'] as num).toDouble();
            final ingCurrentStock = (rItem['current_stock'] as num).toDouble();
            final totalDeduct = amountPerCup * item.quantity;

            itemUnitCogs += amountPerCup * unitCost;

            recipeSnapshotList.add({
              'ingredient_id': ingId,
              'ingredient_name': rItem['ingredient_name'],
              'amount_per_cup': amountPerCup,
              'unit_cost': unitCost,
              'total_deducted': totalDeduct,
            });

            // Deduct stock from ingredients table
            final newIngStock = ingCurrentStock - totalDeduct;
            await txn.update(
              'ingredients',
              {
                'current_stock': newIngStock,
                'updated_at': now,
              },
              where: 'id = ?',
              whereArgs: [ingId],
            );

            // Deduct from stock_batches (FEFO: earliest expiry first)
            double remainingToDeduct = totalDeduct;
            final batchRows = await txn.query(
              'stock_batches',
              where: 'ingredient_id = ? AND remaining_quantity > 0 AND is_active = 1',
              whereArgs: [ingId],
              orderBy: 'expiry_date ASC, received_date ASC',
            );

            for (final b in batchRows) {
              if (remainingToDeduct <= 0) break;
              final bId = b['id'] as String;
              final bRemaining = (b['remaining_quantity'] as num).toDouble();
              final take = bRemaining >= remainingToDeduct ? remainingToDeduct : bRemaining;

              await txn.update(
                'stock_batches',
                {
                  'remaining_quantity': bRemaining - take,
                  'is_active': (bRemaining - take) > 0 ? 1 : 0,
                },
                where: 'id = ?',
                whereArgs: [bId],
              );
              remainingToDeduct -= take;
            }

            // Log stock movement
            await txn.insert('stock_movements', {
              'id': IdGenerator.generateId(prefix: 'sm'),
              'ingredient_id': ingId,
              'movement_type': 'SALE',
              'quantity_change': -totalDeduct,
              'quantity_before': ingCurrentStock,
              'quantity_after': newIngStock,
              'reference_id': trxNumber,
              'reason': 'Penjualan ${item.productName} (${item.quantity} porsi)',
              'user_id': cashierId,
              'created_at': now,
            });
          }
        }

        // Process modifiers (extra sugar, ice, toppings)
        double extraCogsTotal = 0.0;
        final List<TransactionModifierModel> processedMods = [];

        for (final mod in item.modifiers) {
          final modId = IdGenerator.generateId(prefix: 'tm');
          double modExtraCogs = 0.0;

          if (mod.modifierId != null) {
            final modData = await txn.query('modifiers', where: 'id = ?', whereArgs: [mod.modifierId]);
            if (modData.isNotEmpty) {
              final ingId = modData.first['ingredient_id'] as String?;
              final ingAmt = (modData.first['ingredient_amount'] as num? ?? 0.0).toDouble();

              if (ingId != null && ingAmt > 0) {
                final ingRows = await txn.query('ingredients', where: 'id = ?', whereArgs: [ingId]);
                if (ingRows.isNotEmpty) {
                  final ingCost = (ingRows.first['cost_per_unit'] as num).toDouble();
                  final ingCurrentStock = (ingRows.first['current_stock'] as num).toDouble();
                  final totalModDeduct = ingAmt * item.quantity;
                  modExtraCogs = ingAmt * ingCost;
                  extraCogsTotal += modExtraCogs;

                  final newStock = ingCurrentStock - totalModDeduct;
                  await txn.update(
                    'ingredients',
                    {'current_stock': newStock, 'updated_at': now},
                    where: 'id = ?',
                    whereArgs: [ingId],
                  );

                  await txn.insert('stock_movements', {
                    'id': IdGenerator.generateId(prefix: 'sm'),
                    'ingredient_id': ingId,
                    'movement_type': 'SALE',
                    'quantity_change': -totalModDeduct,
                    'quantity_before': ingCurrentStock,
                    'quantity_after': newStock,
                    'reference_id': trxNumber,
                    'reason': 'Topping/Modifikasi ${mod.name} (${item.quantity}x)',
                    'user_id': cashierId,
                    'created_at': now,
                  });
                }
              }
            }
          }

          final trxMod = TransactionModifierModel(
            id: modId,
            transactionItemId: itemId,
            modifierId: mod.modifierId,
            groupName: mod.groupName,
            name: mod.name,
            extraPrice: mod.extraPrice,
            extraCogs: modExtraCogs,
          );
          processedMods.add(trxMod);
        }

        final finalItemUnitCogs = itemUnitCogs + extraCogsTotal;
        final totalItemCogs = finalItemUnitCogs * item.quantity;
        calculatedTotalCogs += totalItemCogs;

        final processedItem = TransactionItemModel(
          id: itemId,
          transactionId: trxId,
          productId: item.productId,
          productName: item.productName,
          variantId: item.variantId,
          variantName: item.variantName,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          subtotal: item.subtotal,
          unitCogs: finalItemUnitCogs,
          totalCogs: totalItemCogs,
          notes: item.notes,
          recipeSnapshotJson: jsonEncode(recipeSnapshotList),
          modifiers: processedMods,
        );
        processedItems.add(processedItem);
      }

      final grossProfit = finalAmount - calculatedTotalCogs;

      // 2. Insert into transactions table
      final trx = TransactionModel(
        id: trxId,
        transactionNumber: trxNumber,
        storeId: storeId ?? 'store_main',
        shiftId: effectiveShiftId,
        cashierId: cashierId,
        cashierName: cashierName,
        totalAmount: totalAmount,
        discountAmount: discountAmount,
        finalAmount: finalAmount,
        totalCogs: calculatedTotalCogs,
        grossProfit: grossProfit,
        paymentMethod: paymentMethod,
        cashReceived: cashReceived,
        qrisAmount: qrisAmount,
        changeAmount: changeAmount,
        status: AppConstants.statusCompleted,
        notes: notes,
        createdAt: now,
        items: processedItems,
      );

      await txn.insert('transactions', trx.toMap());

      // 3. Insert child items and modifiers (respecting foreign key order)
      for (final pItem in processedItems) {
        await txn.insert('transaction_items', pItem.toMap());
        for (final pMod in pItem.modifiers) {
          await txn.insert('transaction_modifiers', pMod.toMap());
        }
      }

      // 3. Record Payments
      final List<PaymentModel> paymentRecords = [];
      if (paymentMethod == AppConstants.paymentCash) {
        final p = PaymentModel(
          id: IdGenerator.generateId(prefix: 'pay'),
          transactionId: trxId,
          paymentMethod: AppConstants.paymentCash,
          amount: finalAmount,
          createdAt: now,
        );
        paymentRecords.add(p);
        await txn.insert('payments', p.toMap());
      } else if (paymentMethod == AppConstants.paymentQris) {
        final p = PaymentModel(
          id: IdGenerator.generateId(prefix: 'pay'),
          transactionId: trxId,
          paymentMethod: AppConstants.paymentQris,
          amount: finalAmount,
          createdAt: now,
        );
        paymentRecords.add(p);
        await txn.insert('payments', p.toMap());
      } else if (paymentMethod == AppConstants.paymentSplit) {
        final cashPart = finalAmount - qrisAmount;
        if (cashPart > 0) {
          final pCash = PaymentModel(
            id: IdGenerator.generateId(prefix: 'pay'),
            transactionId: trxId,
            paymentMethod: AppConstants.paymentCash,
            amount: cashPart,
            createdAt: now,
          );
          paymentRecords.add(pCash);
          await txn.insert('payments', pCash.toMap());
        }
        if (qrisAmount > 0) {
          final pQris = PaymentModel(
            id: IdGenerator.generateId(prefix: 'pay'),
            transactionId: trxId,
            paymentMethod: AppConstants.paymentQris,
            amount: qrisAmount,
            createdAt: now,
          );
          paymentRecords.add(pQris);
          await txn.insert('payments', pQris.toMap());
        }
      }

      // 4. Update Shift Sales on the active open shift
      double shiftCashAdd = 0.0;
      double shiftQrisAdd = 0.0;

      if (paymentMethod == AppConstants.paymentCash) {
        shiftCashAdd = finalAmount;
      } else if (paymentMethod == AppConstants.paymentQris) {
        shiftQrisAdd = finalAmount;
      } else if (paymentMethod == AppConstants.paymentSplit) {
        shiftQrisAdd = qrisAmount;
        shiftCashAdd = finalAmount - qrisAmount;
      }

      await txn.rawUpdate('''
        UPDATE shifts
        SET total_cash_sales = total_cash_sales + ?,
            total_qris_sales = total_qris_sales + ?,
            expected_cash = initial_cash + (total_cash_sales + ?) - total_cash_expenses
        WHERE id = ? AND status = 'OPEN'
      ''', [shiftCashAdd, shiftQrisAdd, shiftCashAdd, effectiveShiftId]);

      completedTrx = TransactionModel.fromMap(
        trx.toMap(),
        items: processedItems,
        payments: paymentRecords,
      );
    });

    return completedTrx!;
  }

  // Cancel Transaction
  Future<void> cancelTransaction({
    required String transactionId,
    required String cancelledByUserId,
    required String cancelledByName,
    required String cancellationReason,
    required bool shouldRestock,
  }) async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      final trxRows = await txn.query('transactions', where: 'id = ?', whereArgs: [transactionId]);
      if (trxRows.isEmpty) throw Exception('Transaksi tidak ditemukan');

      final trx = TransactionModel.fromMap(trxRows.first);
      if (trx.isCancelled) throw Exception('Transaksi sudah dibatalkan sebelumnya');

      final now = DateTime.now().toIso8601String();

      // Update transaction status
      await txn.update(
        'transactions',
        {
          'status': AppConstants.statusCancelled,
          'cancelled_at': now,
          'cancelled_by': cancelledByName,
          'cancellation_reason': cancellationReason,
          'is_restocked': shouldRestock ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [transactionId],
      );

      // If restock is allowed (materials not yet consumed)
      if (shouldRestock) {
        final itemRows = await txn.query('transaction_items', where: 'transaction_id = ?', whereArgs: [transactionId]);
        for (final item in itemRows) {
          final snapshotJson = item['recipe_snapshot_json'] as String?;
          if (snapshotJson != null && snapshotJson.isNotEmpty) {
            try {
              final List<dynamic> list = jsonDecode(snapshotJson);
              for (final entry in list) {
                final ingId = entry['ingredient_id'] as String;
                final totalDeducted = (entry['total_deducted'] as num).toDouble();

                final ingRes = await txn.query('ingredients', where: 'id = ?', whereArgs: [ingId]);
                if (ingRes.isNotEmpty) {
                  final currStock = (ingRes.first['current_stock'] as num).toDouble();
                  final newStock = currStock + totalDeducted;

                  await txn.update(
                    'ingredients',
                    {'current_stock': newStock, 'updated_at': now},
                    where: 'id = ?',
                    whereArgs: [ingId],
                  );

                  await txn.insert('stock_movements', {
                    'id': IdGenerator.generateId(prefix: 'sm'),
                    'ingredient_id': ingId,
                    'movement_type': 'CANCELLATION',
                    'quantity_change': totalDeducted,
                    'quantity_before': currStock,
                    'quantity_after': newStock,
                    'reference_id': trx.transactionNumber,
                    'reason': 'Pengembalian stok pembatalan transaksi: $cancellationReason',
                    'user_id': cancelledByUserId,
                    'created_at': now,
                  });
                }
              }
            } catch (_) {}
          }
        }
      }

      // Revert shift cash/qris amounts if shift is still OPEN
      if (trx.shiftId != null) {
        double revCash = 0.0;
        double revQris = 0.0;
        if (trx.paymentMethod == AppConstants.paymentCash) {
          revCash = trx.finalAmount;
        } else if (trx.paymentMethod == AppConstants.paymentQris) {
          revQris = trx.finalAmount;
        } else if (trx.paymentMethod == AppConstants.paymentSplit) {
          revQris = trx.qrisAmount;
          revCash = trx.finalAmount - trx.qrisAmount;
        }

        await txn.rawUpdate('''
          UPDATE shifts
          SET total_cash_sales = total_cash_sales - ?,
              total_qris_sales = total_qris_sales - ?,
              expected_cash = initial_cash + (total_cash_sales - ?) - total_cash_expenses
          WHERE id = ? AND status = 'OPEN'
        ''', [revCash, revQris, revCash, trx.shiftId]);
      }

      await AuditLogger.log(
        action: 'TRANSACTION_CANCEL',
        entityType: 'TRANSACTION',
        entityId: transactionId,
        userId: cancelledByUserId,
        userName: cancelledByName,
        reason: 'Pembatalan ${trx.transactionNumber}: $cancellationReason (Restock: $shouldRestock)',
        db: txn,
      );
    });
  }

  // Get Transactions
  Future<List<TransactionModel>> getTransactions({
    String? query,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    int limit = 50,
  }) async {
    final db = await _appDb.database;
    String sql = 'SELECT * FROM transactions WHERE 1=1';
    final List<dynamic> args = [];

    if (status != null && status.isNotEmpty) {
      sql += ' AND status = ?';
      args.add(status);
    }
    if (startDate != null) {
      sql += ' AND created_at >= ?';
      args.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      sql += ' AND created_at <= ?';
      args.add(endDate.toIso8601String());
    }
    if (query != null && query.trim().isNotEmpty) {
      sql += ' AND (transaction_number LIKE ? OR cashier_name LIKE ?)';
      final q = '%${query.trim()}%';
      args.add(q);
      args.add(q);
    }

    sql += ' ORDER BY created_at DESC LIMIT ?';
    args.add(limit);

    final res = await db.rawQuery(sql, args);
    final List<TransactionModel> list = [];

    for (final row in res) {
      final trxId = row['id'] as String;
      final itemRows = await db.query('transaction_items', where: 'transaction_id = ?', whereArgs: [trxId]);
      final List<TransactionItemModel> items = [];

      for (final iRow in itemRows) {
        final itemId = iRow['id'] as String;
        final modRows = await db.query('transaction_modifiers', where: 'transaction_item_id = ?', whereArgs: [itemId]);
        final mods = modRows.map((m) => TransactionModifierModel.fromMap(m)).toList();
        items.add(TransactionItemModel.fromMap(iRow, modifiers: mods));
      }

      final payRows = await db.query('payments', where: 'transaction_id = ?', whereArgs: [trxId]);
      final payments = payRows.map((p) => PaymentModel.fromMap(p)).toList();

      list.add(TransactionModel.fromMap(row, items: items, payments: payments));
    }

    return list;
  }
}
