import 'package:sqflite/sqflite.dart';
import '../../core/database/app_database.dart';
import '../../core/security/audit_logger.dart';
import '../../core/utils/id_generator.dart';
import '../models/category_model.dart';
import '../models/modifier_group_model.dart';
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

      // Get assigned modifier groups for product
      final grpRows = await db.query(
        'product_modifier_groups',
        where: 'product_id = ?',
        whereArgs: [pId],
        orderBy: 'display_order ASC',
      );
      final modifierGroups = grpRows.map((r) => r['group_name'] as String).toList();

      products.add(ProductModel.fromMap(row, variants: variants, cogs: estimatedCogs, modifierGroups: modifierGroups));
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

    final grpRows = await db.query(
      'product_modifier_groups',
      where: 'product_id = ?',
      whereArgs: [id],
      orderBy: 'display_order ASC',
    );
    final modifierGroups = grpRows.map((r) => r['group_name'] as String).toList();

    return ProductModel.fromMap(res.first, variants: variants, modifierGroups: modifierGroups);
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

      // Save assigned modifier groups
      await txn.delete('product_modifier_groups', where: 'product_id = ?', whereArgs: [product.id]);
      for (int i = 0; i < product.modifierGroups.length; i++) {
        await txn.insert('product_modifier_groups', {
          'product_id': product.id,
          'group_name': product.modifierGroups[i],
          'display_order': i + 1,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
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
      await txn.delete('product_modifier_groups', where: 'product_id = ?', whereArgs: [id]);
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

  // Modifiers & Modifier Groups
  Future<List<ModifierGroupModel>> getModifierGroups({bool activeOnly = true}) async {
    final db = await _appDb.database;
    final groupRows = await db.query('modifier_groups', orderBy: 'display_order ASC, name ASC');

    if (groupRows.isEmpty) {
      final defaultGroups = [
        ModifierGroupModel(id: 'mod_grp_gula', name: 'Level Gula', selectionType: 'SINGLE', isRequired: true, displayOrder: 1),
        ModifierGroupModel(id: 'mod_grp_es', name: 'Level Es Batu', selectionType: 'SINGLE', isRequired: true, displayOrder: 2),
        ModifierGroupModel(id: 'mod_grp_topping', name: 'Topping Tambahan', selectionType: 'MULTIPLE', isRequired: false, displayOrder: 3),
      ];
      for (final g in defaultGroups) {
        await db.insert('modifier_groups', g.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      return getModifierGroups(activeOnly: activeOnly);
    }

    final List<ModifierGroupModel> result = [];
    for (final row in groupRows) {
      final grpName = row['name'] as String;
      final optRows = await db.query(
        'modifiers',
        where: activeOnly ? 'group_name = ? AND is_active = 1' : 'group_name = ?',
        whereArgs: [grpName],
        orderBy: 'extra_price ASC, name ASC',
      );
      final options = optRows.map((m) => ModifierModel.fromMap(m)).toList();
      result.add(ModifierGroupModel.fromMap(row, options: options));
    }
    return result;
  }

  Future<List<ModifierGroupModel>> getModifiersForProduct(String productId) async {
    final db = await _appDb.database;
    final grpRows = await db.query(
      'product_modifier_groups',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'display_order ASC',
    );
    if (grpRows.isEmpty) return [];

    final assignedNames = grpRows.map((r) => r['group_name'] as String).toSet();
    final allGroups = await getModifierGroups(activeOnly: true);
    return allGroups.where((g) => assignedNames.contains(g.name)).toList();
  }

  Future<void> saveModifierGroup(ModifierGroupModel group) async {
    final db = await _appDb.database;
    await db.insert('modifier_groups', group.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteModifierGroup(String groupName) async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      await txn.delete('modifier_groups', where: 'name = ?', whereArgs: [groupName]);
      await txn.delete('modifiers', where: 'group_name = ?', whereArgs: [groupName]);
      await txn.delete('product_modifier_groups', where: 'group_name = ?', whereArgs: [groupName]);
    });
  }

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
    // Ensure the group exists in modifier_groups
    final grpExists = await db.query('modifier_groups', where: 'name = ?', whereArgs: [modifier.groupName]);
    if (grpExists.isEmpty) {
      final isMulti = modifier.groupName.toLowerCase().contains('topping') || modifier.groupName.toLowerCase().contains('ekstra');
      await db.insert('modifier_groups', {
        'id': IdGenerator.generateId(prefix: 'grp'),
        'name': modifier.groupName,
        'selection_type': isMulti ? 'MULTIPLE' : 'SINGLE',
        'is_required': 0,
        'display_order': 99,
      });
    }
  }

  Future<void> deleteModifier(String id) async {
    final db = await _appDb.database;
    await db.delete('modifiers', where: 'id = ?', whereArgs: [id]);
  }
}
