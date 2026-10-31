import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../core/database/app_database.dart';
import '../../core/security/audit_logger.dart';
import '../../core/utils/id_generator.dart';
import '../models/ingredient_model.dart';
import '../models/recipe_model.dart';
import '../models/stock_model.dart';

class IngredientRepository {
  final AppDatabase _appDb;
  IngredientRepository([AppDatabase? appDb]) : _appDb = appDb ?? AppDatabase.instance;

  // Ingredients
  Future<List<IngredientModel>> getIngredients({String? query, bool? isPackaging}) async {
    final db = await _appDb.database;
    String sql = 'SELECT * FROM ingredients WHERE 1=1';
    final List<dynamic> args = [];

    if (isPackaging != null) {
      sql += ' AND is_packaging = ?';
      args.add(isPackaging ? 1 : 0);
    }
    if (query != null && query.trim().isNotEmpty) {
      sql += ' AND name LIKE ?';
      args.add('%${query.trim()}%');
    }
    sql += ' ORDER BY name ASC';

    final res = await db.rawQuery(sql, args);
    return res.map((m) => IngredientModel.fromMap(m)).toList();
  }

  Future<List<IngredientModel>> getLowStockIngredients() async {
    final db = await _appDb.database;
    final res = await db.rawQuery('''
      SELECT * FROM ingredients 
      WHERE current_stock <= minimum_stock 
      ORDER BY current_stock ASC
    ''');
    return res.map((m) => IngredientModel.fromMap(m)).toList();
  }

  Future<IngredientModel?> getIngredientById(String id) async {
    final db = await _appDb.database;
    final res = await db.query('ingredients', where: 'id = ?', whereArgs: [id]);
    if (res.isEmpty) return null;
    return IngredientModel.fromMap(res.first);
  }

  Future<void> saveIngredient(IngredientModel ingredient, {String? userId}) async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final existing = await txn.query('ingredients', where: 'id = ?', whereArgs: [ingredient.id]);

      if (existing.isEmpty) {
        await txn.insert('ingredients', {
          ...ingredient.toMap(),
          'created_at': now,
          'updated_at': now,
        });

        // Add initial stock movement if starting with stock > 0
        if (ingredient.currentStock > 0) {
          final batchId = IdGenerator.generateId(prefix: 'bat');
          await txn.insert('stock_batches', {
            'id': batchId,
            'ingredient_id': ingredient.id,
            'batch_number': 'BATCH-INIT',
            'initial_quantity': ingredient.currentStock,
            'remaining_quantity': ingredient.currentStock,
            'unit_cost': ingredient.costPerUnit,
            'received_date': now.substring(0, 10),
            'is_active': 1,
          });

          await txn.insert('stock_movements', {
            'id': IdGenerator.generateId(prefix: 'sm'),
            'ingredient_id': ingredient.id,
            'batch_id': batchId,
            'movement_type': 'PURCHASE',
            'quantity_change': ingredient.currentStock,
            'quantity_before': 0.0,
            'quantity_after': ingredient.currentStock,
            'reference_id': 'INIT',
            'reason': 'Stok awal bahan',
            'user_id': userId,
            'created_at': now,
          });
        }
      } else {
        await txn.update(
          'ingredients',
          {
            ...ingredient.toMap(),
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [ingredient.id],
        );
      }

      await AuditLogger.log(
        action: existing.isEmpty ? 'INGREDIENT_CREATE' : 'INGREDIENT_UPDATE',
        entityType: 'INGREDIENT',
        entityId: ingredient.id,
        userId: userId,
        reason: 'Simpan bahan ${ingredient.name}',
        db: txn,
      );
    });
  }

  // Stock Opname / Penyesuaian Stok
  Future<void> adjustStock({
    required String ingredientId,
    required double actualStock,
    required String reason,
    required String userId,
    String? userName,
  }) async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      final ingRows = await txn.query('ingredients', where: 'id = ?', whereArgs: [ingredientId]);
      if (ingRows.isEmpty) throw Exception('Bahan tidak ditemukan');

      final currentStock = (ingRows.first['current_stock'] as num).toDouble();
      final diff = actualStock - currentStock;
      final now = DateTime.now().toIso8601String();

      // Update ingredient table
      await txn.update(
        'ingredients',
        {
          'current_stock': actualStock,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [ingredientId],
      );

      // Record in stock_movements
      await txn.insert('stock_movements', {
        'id': IdGenerator.generateId(prefix: 'sm'),
        'ingredient_id': ingredientId,
        'movement_type': 'ADJUSTMENT',
        'quantity_change': diff,
        'quantity_before': currentStock,
        'quantity_after': actualStock,
        'reference_id': 'OPNAME-${DateTime.now().millisecondsSinceEpoch}',
        'reason': reason,
        'user_id': userId,
        'created_at': now,
      });

      // Audit log
      await AuditLogger.log(
        action: 'STOCK_ADJUSTMENT',
        entityType: 'INGREDIENT',
        entityId: ingredientId,
        userId: userId,
        userName: userName,
        oldValue: currentStock.toString(),
        newValue: actualStock.toString(),
        reason: reason,
        db: txn,
      );
    });
  }

  // Recipes
  Future<RecipeModel?> getRecipeForProduct(String productId, {String? variantId}) async {
    final db = await _appDb.database;
    String sql = 'SELECT * FROM recipes WHERE product_id = ?';
    final List<dynamic> args = [productId];

    if (variantId != null && variantId.isNotEmpty) {
      sql += ' AND variant_id = ?';
      args.add(variantId);
    } else {
      sql += ' AND (variant_id IS NULL OR variant_id = "")';
    }

    final res = await db.rawQuery(sql, args);
    if (res.isEmpty) {
      // Fallback: any recipe for this product
      final anyRes = await db.query('recipes', where: 'product_id = ?', whereArgs: [productId], limit: 1);
      if (anyRes.isEmpty) return null;
      return _loadRecipeDetails(db, anyRes.first);
    }
    return _loadRecipeDetails(db, res.first);
  }

  Future<RecipeModel> _loadRecipeDetails(DatabaseExecutor db, Map<String, dynamic> recipeRow) async {
    final recipeId = recipeRow['id'] as String;
    final itemRows = await db.rawQuery('''
      SELECT ri.*, i.name as ingredient_name, i.unit, i.cost_per_unit
      FROM recipe_items ri
      JOIN ingredients i ON ri.ingredient_id = i.id
      WHERE ri.recipe_id = ?
    ''', [recipeId]);

    final items = itemRows.map((m) => RecipeItemModel.fromMap(m)).toList();
    return RecipeModel.fromMap(recipeRow, items: items);
  }

  Future<void> saveRecipe({
    required RecipeModel recipe,
    required List<RecipeItemModel> items,
    String? userId,
  }) async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final existing = await txn.query('recipes', where: 'id = ?', whereArgs: [recipe.id]);

      int newVersion = recipe.version;
      if (existing.isNotEmpty) {
        newVersion = (existing.first['version'] as int? ?? 1) + 1;
        await txn.update(
          'recipes',
          {
            'name': recipe.name,
            'version': newVersion,
          },
          where: 'id = ?',
          whereArgs: [recipe.id],
        );
      } else {
        await txn.insert('recipes', {
          ...recipe.toMap(),
          'version': newVersion,
          'created_at': now,
        });
      }

      // Delete old recipe items
      await txn.delete('recipe_items', where: 'recipe_id = ?', whereArgs: [recipe.id]);

      // Insert new recipe items
      for (final item in items) {
        await txn.insert('recipe_items', {
          'id': IdGenerator.generateId(prefix: 'ri'),
          'recipe_id': recipe.id,
          'ingredient_id': item.ingredientId,
          'amount_required': item.amountRequired,
        });
      }

      // Save version snapshot in recipe_versions table
      final snapshot = {
        'recipe_id': recipe.id,
        'product_id': recipe.productId,
        'variant_id': recipe.variantId,
        'version': newVersion,
        'items': items.map((i) => {
          'ingredient_id': i.ingredientId,
          'ingredient_name': i.ingredientName,
          'amount_required': i.amountRequired,
          'unit_cost': i.unitCost,
        }).toList(),
      };

      await txn.insert('recipe_versions', {
        'id': IdGenerator.generateId(prefix: 'rv'),
        'recipe_id': recipe.id,
        'version': newVersion,
        'snapshot_json': jsonEncode(snapshot),
        'created_at': now,
        'created_by': userId,
      });

      await AuditLogger.log(
        action: 'RECIPE_UPDATE',
        entityType: 'RECIPE',
        entityId: recipe.id,
        userId: userId,
        reason: 'Pembaruan resep ${recipe.name} versi $newVersion',
        db: txn,
      );
    });
  }

  // Stock Movements & Batches
  Future<List<StockMovementModel>> getStockMovements({String? ingredientId, int limit = 100}) async {
    final db = await _appDb.database;
    String sql = '''
      SELECT sm.*, i.name as ingredient_name
      FROM stock_movements sm
      JOIN ingredients i ON sm.ingredient_id = i.id
    ''';
    final List<dynamic> args = [];
    if (ingredientId != null && ingredientId.isNotEmpty) {
      sql += ' WHERE sm.ingredient_id = ?';
      args.add(ingredientId);
    }
    sql += ' ORDER BY sm.created_at DESC LIMIT ?';
    args.add(limit);

    final res = await db.rawQuery(sql, args);
    return res.map((m) => StockMovementModel.fromMap(m)).toList();
  }

  Future<List<StockBatchModel>> getBatches({String? ingredientId, bool nearExpiryOnly = false}) async {
    final db = await _appDb.database;
    String sql = '''
      SELECT sb.*, i.name as ingredient_name
      FROM stock_batches sb
      JOIN ingredients i ON sb.ingredient_id = i.id
      WHERE sb.remaining_quantity > 0 AND sb.is_active = 1
    ''';
    final List<dynamic> args = [];
    if (ingredientId != null) {
      sql += ' AND sb.ingredient_id = ?';
      args.add(ingredientId);
    }
    sql += ' ORDER BY sb.expiry_date ASC, sb.received_date ASC';

    final res = await db.rawQuery(sql, args);
    final batches = res.map((m) => StockBatchModel.fromMap(m)).toList();

    if (nearExpiryOnly) {
      return batches.where((b) => b.isNearExpiry || b.isExpired).toList();
    }
    return batches;
  }
}
