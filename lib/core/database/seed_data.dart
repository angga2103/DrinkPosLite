import 'package:sqflite/sqflite.dart';
import '../security/pin_security.dart';

class SeedData {
  static Future<void> populateInitialData(Database db) async {
    final now = DateTime.now().toIso8601String();

    // 1. Store Setup
    await db.insert('stores', {
      'id': 'store_main',
      'name': 'Kedai Minuman Ansor',
      'address': 'Jl. Ahmad Yani No. 12, Indonesia',
      'phone': '081775700114',
      'receipt_header': 'DRINKPOS LITE\nNikmat & Segar Setiap Saat',
      'receipt_footer': 'Terima kasih atas kunjungan Anda!\nFollow IG: @ansor.studi',
      'currency': 'IDR',
      'created_at': now,
      'updated_at': now,
    });

    // 2. Default Users (Owner, Manager, Cashier)
    // Owner PIN: 1234
    await db.insert('users', {
      'id': 'usr_owner',
      'name': 'Pemilik (Owner)',
      'role': 'OWNER',
      'pin_hash': PinSecurity.hashPin('1234'),
      'is_active': 1,
      'is_locked': 0,
      'failed_attempts': 0,
      'join_date': now.substring(0, 10),
      'monthly_salary': 0,
      'created_at': now,
      'updated_at': now,
    });

    // Manager PIN: 2345
    await db.insert('users', {
      'id': 'usr_manager',
      'name': 'Budi (Manager)',
      'role': 'MANAGER',
      'pin_hash': PinSecurity.hashPin('2345'),
      'is_active': 1,
      'is_locked': 0,
      'failed_attempts': 0,
      'join_date': now.substring(0, 10),
      'monthly_salary': 3000000,
      'created_at': now,
      'updated_at': now,
    });

    // Cashier PIN: 3456
    await db.insert('users', {
      'id': 'usr_cashier',
      'name': 'Siti (Kasir)',
      'role': 'CASHIER',
      'pin_hash': PinSecurity.hashPin('3456'),
      'is_active': 1,
      'is_locked': 0,
      'failed_attempts': 0,
      'join_date': now.substring(0, 10),
      'monthly_salary': 2200000,
      'created_at': now,
      'updated_at': now,
    });

    // 3. Default Categories
    await db.insert('categories', {'id': 'cat_tea', 'name': 'Es Teh & Tea Series', 'display_order': 1, 'is_active': 1});
    await db.insert('categories', {'id': 'cat_coffee', 'name': 'Kopi & Coffee Series', 'display_order': 2, 'is_active': 1});
    await db.insert('categories', {'id': 'cat_choco', 'name': 'Cokelat & Milk Series', 'display_order': 3, 'is_active': 1});
    await db.insert('categories', {'id': 'cat_juice', 'name': 'Jus Buah Segar', 'display_order': 4, 'is_active': 1});

    // 4. Default Ingredients & Packaging
    final ingredientsData = [
      {'id': 'ing_tea', 'name': 'Daun Teh Wangi', 'unit': 'gram', 'current_stock': 2000.0, 'minimum_stock': 200.0, 'cost_per_unit': 50.0, 'last_buy_price': 50.0, 'is_packaging': 0},
      {'id': 'ing_sugar', 'name': 'Gula Pasir', 'unit': 'gram', 'current_stock': 5000.0, 'minimum_stock': 500.0, 'cost_per_unit': 18.0, 'last_buy_price': 18.0, 'is_packaging': 0},
      {'id': 'ing_coffee', 'name': 'Biji Kopi Robusta', 'unit': 'gram', 'current_stock': 1500.0, 'minimum_stock': 200.0, 'cost_per_unit': 120.0, 'last_buy_price': 120.0, 'is_packaging': 0},
      {'id': 'ing_choco', 'name': 'Bubuk Cokelat Premium', 'unit': 'gram', 'current_stock': 2000.0, 'minimum_stock': 300.0, 'cost_per_unit': 85.0, 'last_buy_price': 85.0, 'is_packaging': 0},
      {'id': 'ing_milk', 'name': 'Susu UHT Segar', 'unit': 'ml', 'current_stock': 6000.0, 'minimum_stock': 1000.0, 'cost_per_unit': 20.0, 'last_buy_price': 20.0, 'is_packaging': 0},
      {'id': 'ing_boba', 'name': 'Topping Boba Kenyal', 'unit': 'gram', 'current_stock': 1500.0, 'minimum_stock': 300.0, 'cost_per_unit': 45.0, 'last_buy_price': 45.0, 'is_packaging': 0},
      {'id': 'ing_jelly', 'name': 'Topping Jelly Cincau', 'unit': 'gram', 'current_stock': 1500.0, 'minimum_stock': 300.0, 'cost_per_unit': 35.0, 'last_buy_price': 35.0, 'is_packaging': 0},
      {'id': 'ing_ice', 'name': 'Es Batu Kristal', 'unit': 'gram', 'current_stock': 15000.0, 'minimum_stock': 2000.0, 'cost_per_unit': 3.0, 'last_buy_price': 3.0, 'is_packaging': 0},
      {'id': 'ing_cup', 'name': 'Cup Minuman 16oz', 'unit': 'pcs', 'current_stock': 500.0, 'minimum_stock': 50.0, 'cost_per_unit': 550.0, 'last_buy_price': 550.0, 'is_packaging': 1},
      {'id': 'ing_cup_large', 'name': 'Cup Minuman 22oz (Large)', 'unit': 'pcs', 'current_stock': 400.0, 'minimum_stock': 50.0, 'cost_per_unit': 700.0, 'last_buy_price': 700.0, 'is_packaging': 1},
      {'id': 'ing_lid', 'name': 'Sealer Tutup Cup & Sedotan', 'unit': 'pcs', 'current_stock': 1000.0, 'minimum_stock': 100.0, 'cost_per_unit': 200.0, 'last_buy_price': 200.0, 'is_packaging': 1},
    ];

    for (var ing in ingredientsData) {
      await db.insert('ingredients', {
        ...ing,
        'created_at': now,
        'updated_at': now,
      });

      // Insert initial stock batch
      await db.insert('stock_batches', {
        'id': 'batch_${ing['id']}_01',
        'ingredient_id': ing['id'],
        'batch_number': 'BATCH-INIT-01',
        'initial_quantity': ing['current_stock'],
        'remaining_quantity': ing['current_stock'],
        'unit_cost': ing['cost_per_unit'],
        'expiry_date': DateTime.now().add(const Duration(days: 90)).toIso8601String().substring(0, 10),
        'received_date': now.substring(0, 10),
        'is_active': 1,
      });

      // Insert initial stock movement log
      await db.insert('stock_movements', {
        'id': 'sm_${ing['id']}_init',
        'ingredient_id': ing['id'],
        'batch_id': 'batch_${ing['id']}_01',
        'movement_type': 'PURCHASE',
        'quantity_change': ing['current_stock'],
        'quantity_before': 0.0,
        'quantity_after': ing['current_stock'],
        'reference_id': 'INIT-SETUP',
        'reason': 'Stok awal sistem',
        'user_id': 'usr_owner',
        'created_at': now,
      });
    }

    // 5. Default Modifiers
    // Sugar levels
    await db.insert('modifiers', {'id': 'mod_sug_100', 'group_name': 'Gula', 'name': 'Gula Normal (100%)', 'extra_price': 0, 'is_active': 1});
    await db.insert('modifiers', {'id': 'mod_sug_50', 'group_name': 'Gula', 'name': 'Gula Sedikit (50%)', 'extra_price': 0, 'is_active': 1});
    await db.insert('modifiers', {'id': 'mod_sug_0', 'group_name': 'Gula', 'name': 'Tanpa Gula (0%)', 'extra_price': 0, 'is_active': 1});

    // Ice levels
    await db.insert('modifiers', {'id': 'mod_ice_norm', 'group_name': 'Es', 'name': 'Es Normal', 'extra_price': 0, 'is_active': 1});
    await db.insert('modifiers', {'id': 'mod_ice_less', 'group_name': 'Es', 'name': 'Es Sedikit', 'extra_price': 0, 'is_active': 1});
    await db.insert('modifiers', {'id': 'mod_ice_none', 'group_name': 'Es', 'name': 'Tanpa Es', 'extra_price': 0, 'is_active': 1});

    // Toppings
    await db.insert('modifiers', {'id': 'mod_top_boba', 'group_name': 'Topping', 'name': 'Boba Brown Sugar', 'extra_price': 3000, 'ingredient_id': 'ing_boba', 'ingredient_amount': 30.0, 'is_active': 1});
    await db.insert('modifiers', {'id': 'mod_top_jelly', 'group_name': 'Topping', 'name': 'Jelly Cincau Segar', 'extra_price': 2500, 'ingredient_id': 'ing_jelly', 'ingredient_amount': 25.0, 'is_active': 1});

    // 6. Default Products
    // Product 1: Es Teh Solo Manis
    await db.insert('products', {
      'id': 'prod_tea_solo',
      'category_id': 'cat_tea',
      'name': 'Es Teh Solo Segar',
      'description': 'Teh melati racikan khas Solo, wangi dan legit.',
      'base_price': 5000,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('product_variants', {'id': 'var_tea_s', 'product_id': 'prod_tea_solo', 'name': 'Small', 'price': 5000, 'is_default': 1, 'is_active': 1});
    await db.insert('product_variants', {'id': 'var_tea_m', 'product_id': 'prod_tea_solo', 'name': 'Medium', 'price': 7000, 'is_default': 0, 'is_active': 1});
    await db.insert('product_variants', {'id': 'var_tea_l', 'product_id': 'prod_tea_solo', 'name': 'Large', 'price': 9000, 'is_default': 0, 'is_active': 1});

    // Recipe for Es Teh Solo (Medium)
    await db.insert('recipes', {'id': 'rec_tea_m', 'product_id': 'prod_tea_solo', 'variant_id': 'var_tea_m', 'name': 'Resep Es Teh Medium', 'version': 1, 'created_at': now});
    await db.insert('recipe_items', {'id': 'ri_tea_1', 'recipe_id': 'rec_tea_m', 'ingredient_id': 'ing_tea', 'amount_required': 15.0});
    await db.insert('recipe_items', {'id': 'ri_tea_2', 'recipe_id': 'rec_tea_m', 'ingredient_id': 'ing_sugar', 'amount_required': 25.0});
    await db.insert('recipe_items', {'id': 'ri_tea_3', 'recipe_id': 'rec_tea_m', 'ingredient_id': 'ing_ice', 'amount_required': 100.0});
    await db.insert('recipe_items', {'id': 'ri_tea_4', 'recipe_id': 'rec_tea_m', 'ingredient_id': 'ing_cup', 'amount_required': 1.0});
    await db.insert('recipe_items', {'id': 'ri_tea_5', 'recipe_id': 'rec_tea_m', 'ingredient_id': 'ing_lid', 'amount_required': 1.0});

    // Product 2: Es Kopi Susu Aren
    await db.insert('products', {
      'id': 'prod_kopi_aren',
      'category_id': 'cat_coffee',
      'name': 'Es Kopi Susu Gula Aren',
      'description': 'Kopi espresso robusta nikmat dipadu susu segar & gula aren.',
      'base_price': 15000,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('product_variants', {'id': 'var_kopi_reg', 'product_id': 'prod_kopi_aren', 'name': 'Regular (16oz)', 'price': 15000, 'is_default': 1, 'is_active': 1});
    await db.insert('product_variants', {'id': 'var_kopi_lrg', 'product_id': 'prod_kopi_aren', 'name': 'Large (22oz)', 'price': 18000, 'is_default': 0, 'is_active': 1});

    // Recipe for Kopi Aren (Regular)
    await db.insert('recipes', {'id': 'rec_kopi_reg', 'product_id': 'prod_kopi_aren', 'variant_id': 'var_kopi_reg', 'name': 'Resep Kopi Aren Regular', 'version': 1, 'created_at': now});
    await db.insert('recipe_items', {'id': 'ri_kopi_1', 'recipe_id': 'rec_kopi_reg', 'ingredient_id': 'ing_coffee', 'amount_required': 20.0});
    await db.insert('recipe_items', {'id': 'ri_kopi_2', 'recipe_id': 'rec_kopi_reg', 'ingredient_id': 'ing_milk', 'amount_required': 120.0});
    await db.insert('recipe_items', {'id': 'ri_kopi_3', 'recipe_id': 'rec_kopi_reg', 'ingredient_id': 'ing_sugar', 'amount_required': 20.0});
    await db.insert('recipe_items', {'id': 'ri_kopi_4', 'recipe_id': 'rec_kopi_reg', 'ingredient_id': 'ing_ice', 'amount_required': 100.0});
    await db.insert('recipe_items', {'id': 'ri_kopi_5', 'recipe_id': 'rec_kopi_reg', 'ingredient_id': 'ing_cup', 'amount_required': 1.0});
    await db.insert('recipe_items', {'id': 'ri_kopi_6', 'recipe_id': 'rec_kopi_reg', 'ingredient_id': 'ing_lid', 'amount_required': 1.0});

    // Product 3: Cokelat Lava Ice
    await db.insert('products', {
      'id': 'prod_choco_lava',
      'category_id': 'cat_choco',
      'name': 'Cokelat Lava Creamy',
      'description': 'Cokelat premium pekat dipadukan susu dingin lembut.',
      'base_price': 14000,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('product_variants', {'id': 'var_choco_reg', 'product_id': 'prod_choco_lava', 'name': 'Regular (16oz)', 'price': 14000, 'is_default': 1, 'is_active': 1});
    await db.insert('product_variants', {'id': 'var_choco_lrg', 'product_id': 'prod_choco_lava', 'name': 'Large (22oz)', 'price': 17000, 'is_default': 0, 'is_active': 1});

    // Recipe for Cokelat Lava
    await db.insert('recipes', {'id': 'rec_choco_reg', 'product_id': 'prod_choco_lava', 'variant_id': 'var_choco_reg', 'name': 'Resep Cokelat Regular', 'version': 1, 'created_at': now});
    await db.insert('recipe_items', {'id': 'ri_cho_1', 'recipe_id': 'rec_choco_reg', 'ingredient_id': 'ing_choco', 'amount_required': 30.0});
    await db.insert('recipe_items', {'id': 'ri_cho_2', 'recipe_id': 'rec_choco_reg', 'ingredient_id': 'ing_milk', 'amount_required': 100.0});
    await db.insert('recipe_items', {'id': 'ri_cho_3', 'recipe_id': 'rec_choco_reg', 'ingredient_id': 'ing_sugar', 'amount_required': 15.0});
    await db.insert('recipe_items', {'id': 'ri_cho_4', 'recipe_id': 'rec_choco_reg', 'ingredient_id': 'ing_ice', 'amount_required': 100.0});
    await db.insert('recipe_items', {'id': 'ri_cho_5', 'recipe_id': 'rec_choco_reg', 'ingredient_id': 'ing_cup', 'amount_required': 1.0});
    await db.insert('recipe_items', {'id': 'ri_cho_6', 'recipe_id': 'rec_choco_reg', 'ingredient_id': 'ing_lid', 'amount_required': 1.0});

    // 7. Expense Categories
    final defaultExpCategories = [
      {'id': 'expcat_ing', 'name': 'Pembelian Bahan Baku', 'is_system': 1},
      {'id': 'expcat_elec', 'name': 'Listrik & Token', 'is_system': 1},
      {'id': 'expcat_water', 'name': 'Air PDAM / Galon', 'is_system': 1},
      {'id': 'expcat_sal', 'name': 'Gaji Pegawai', 'is_system': 1},
      {'id': 'expcat_trans', 'name': 'Transportasi & Pengiriman', 'is_system': 1},
      {'id': 'expcat_rent', 'name': 'Sewa Tempat & Booth', 'is_system': 1},
      {'id': 'expcat_maint', 'name': 'Perawatan & Kebersihan', 'is_system': 1},
      {'id': 'expcat_other', 'name': 'Operasional Lainnya', 'is_system': 1},
    ];
    for (var cat in defaultExpCategories) {
      await db.insert('expense_categories', cat);
    }

    // 8. Promotions
    await db.insert('promotions', {
      'id': 'promo_disc_3k',
      'name': 'Diskon Spesial Rp3.000',
      'promo_type': 'NOMINAL',
      'discount_value': 3000,
      'min_purchase': 15000,
      'is_active': 1,
      'created_at': now,
    });
    await db.insert('promotions', {
      'id': 'promo_disc_10p',
      'name': 'Diskon Member 10%',
      'promo_type': 'PERCENTAGE',
      'discount_value': 10,
      'min_purchase': 25000,
      'is_active': 1,
      'created_at': now,
    });

    // 9. Initial Audit Log
    await db.insert('audit_logs', {
      'id': 'audit_init',
      'action': 'INIT_DATABASE',
      'entity_type': 'DATABASE',
      'entity_id': 'drinkpos_lite.db',
      'user_id': 'usr_owner',
      'user_name': 'System',
      'reason': 'Inisialisasi sistem DrinkPOS Lite awal',
      'created_at': now,
    });
  }
}
