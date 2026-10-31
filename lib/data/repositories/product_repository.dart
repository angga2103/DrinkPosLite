import 'package:sqflite/sqflite.dart';
import '../../core/database/app_database.dart';
import '../../core/security/audit_logger.dart';
import '../models/category_model.dart';
import '../models/modifier_model.dart';
import '../models/product_model.dart';

class ProductRepository {
  final AppDatabase _appDb;
  ProductRepository([AppDatabase? appDb]) : _appDb = appDb ?? AppDatabase.instance;

  // Categories
  Future<List<CategoryModel>> getCategories({bool activeOnly = true}) async {
    final db = await _appDb.database;
    final where = activeOnly ? 'is_active = 1' : null;
    final res = await db.query('categories', where: where, orderBy: 'display_order ASC, name ASC');
    return res.map((m) => CategoryModel.fromMap(m)).toList();
  }

  Future<void> saveCategory(CategoryModel category) async {
    final db = await _appDb.database;
    await db.insert(
      'categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCategory(String id) async {
    final db = await _appDb.database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // Products
  Future<List<ProductModel>> getProducts({
    String? categoryId,
    String? query,
    bool activeOnly = true,
  }) async {
    final db = await _appDb.database;
    String sql = '''
      SELECT p.*, c.name as category_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE 1=1
    ''';
    final List<dynamic> args = [];

    if (activeOnly) {
      sql += ' AND p.is_active = 1';
    }
    if (categoryId != null && categoryId.isNotEmpty && categoryId != 'ALL') {
      sql += ' AND p.category_id = ?';
      args.add(categoryId);
    }
    if (query != null && query.trim().isNotEmpty) {
      sql += ' AND (p.name LIKE ? OR p.description LIKE ?)';
      final q = '%${query.trim()}%';
      args.add(q);
      args.add(q);
    }
    sql += ' ORDER BY p.name ASC';

    final productRows = await db.rawQuery(sql, args);
    final List<ProductModel> products = [];

    for (final row in productRows) {
      final pId = row['id'] as String;
      final variantRows = await db.query(
        'product_variants',
        where: 'product_id = ? AND is_active = 1',
        whereArgs: [pId],
        orderBy: 'price ASC',
      );
      final variants = variantRows.map((v) => ProductVariantModel.fromMap(v)).toList();

      // Calculate estimated COGS from active recipe if available
      final recipeRows = await db.query('recipes', where: 'product_id = ?', whereArgs: [pId], limit: 1);
      double estimatedCogs = 0.0;
      if (recipeRows.isNotEmpty) {
        final recId = recipeRows.first['id'] as String;
        final itemRows = await db.rawQuery('''
          SELECT ri.amount_required, i.cost_per_unit
          FROM recipe_items ri
          JOIN ingredients i ON ri.ingredient_id = i.id
          WHERE ri.recipe_id = ?
        ''', [recId]);
        for (final item in itemRows) {
          final amt = (item['amount_required'] as num).toDouble();
          final cost = (item['cost_per_unit'] as num).toDouble();
          estimatedCogs += amt * cost;
        }
      }

      products.add(ProductModel.fromMap(row, variants: variants, cogs: estimatedCogs));
    }

    return products;
  }

  Future<ProductModel?> getProductById(String id) async {
    final db = await _appDb.database;
    final res = await db.rawQuery('''
      SELECT p.*, c.name as category_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE p.id = ?
    ''', [id]);
    if (res.isEmpty) return null;

    final variantRows = await db.query(
      'product_variants',
      where: 'product_id = ? AND is_active = 1',
      whereArgs: [id],
      orderBy: 'price ASC',
    );
    final variants = variantRows.map((v) => ProductVariantModel.fromMap(v)).toList();
    return ProductModel.fromMap(res.first, variants: variants);
  }

  Future<void> saveProduct({
    required ProductModel product,
    required List<ProductVariantModel> variants,
    String? updatedByUserId,
  }) async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final existing = await txn.query('products', where: 'id = ?', whereArgs: [product.id]);

      if (existing.isEmpty) {
        await txn.insert('products', {
          ...product.toMap(),
          'created_at': now,
          'updated_at': now,
        });
      } else {
        await txn.update(
          'products',
          {
            ...product.toMap(),
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [product.id],
        );
      }

      // Save variants
      // Delete old removed variants
      final incomingVariantIds = variants.map((v) => v.id).toList();
      await txn.delete(
        'product_variants',
        where: 'product_id = ? AND id NOT IN (${List.filled(incomingVariantIds.length, '?').join(',')})',
        whereArgs: [product.id, ...incomingVariantIds],
      );

      for (final v in variants) {
        await txn.insert(
          'product_variants',
          v.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await AuditLogger.log(
        action: existing.isEmpty ? 'PRODUCT_CREATE' : 'PRODUCT_UPDATE',
        entityType: 'PRODUCT',
        entityId: product.id,
        userId: updatedByUserId,
        reason: 'Simpan produk ${product.name}',
        db: txn,
      );
    });
  }

  Future<void> deleteProduct(String id, {String? userId}) async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      await txn.delete('product_variants', where: 'product_id = ?', whereArgs: [id]);
      await txn.delete('products', where: 'id = ?', whereArgs: [id]);
      await AuditLogger.log(
        action: 'PRODUCT_DELETE',
        entityType: 'PRODUCT',
        entityId: id,
        userId: userId,
        reason: 'Hapus produk',
        db: txn,
      );
    });
  }

  // Modifiers (Sugar, Ice, Toppings)
  Future<List<ModifierModel>> getModifiers({String? groupName, bool activeOnly = true}) async {
    final db = await _appDb.database;
    String? where;
    List<dynamic>? args;

    if (groupName != null && activeOnly) {
      where = 'group_name = ? AND is_active = 1';
      args = [groupName];
    } else if (groupName != null) {
      where = 'group_name = ?';
      args = [groupName];
    } else if (activeOnly) {
      where = 'is_active = 1';
    }

    final res = await db.query('modifiers', where: where, whereArgs: args, orderBy: 'group_name ASC, extra_price ASC, name ASC');
    return res.map((m) => ModifierModel.fromMap(m)).toList();
  }

  Future<void> saveModifier(ModifierModel modifier) async {
    final db = await _appDb.database;
    await db.insert('modifiers', modifier.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteModifier(String id) async {
    final db = await _appDb.database;
    await db.delete('modifiers', where: 'id = ?', whereArgs: [id]);
  }
}
