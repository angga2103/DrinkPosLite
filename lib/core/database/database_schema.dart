class DatabaseSchema {
  static const List<String> createTablesQueries = [
    // 1. Stores
    '''
    CREATE TABLE IF NOT EXISTS stores (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      address TEXT,
      phone TEXT,
      receipt_header TEXT,
      receipt_footer TEXT,
      currency TEXT DEFAULT 'IDR',
      logo_path TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
    ''',

    // 2. Users (Employees)
    '''
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      role TEXT NOT NULL, -- OWNER, MANAGER, CASHIER
      pin_hash TEXT NOT NULL,
      is_active INTEGER DEFAULT 1,
      is_locked INTEGER DEFAULT 0,
      failed_attempts INTEGER DEFAULT 0,
      join_date TEXT,
      monthly_salary REAL DEFAULT 0,
      shift_start_time TEXT DEFAULT '08:00',
      shift_end_time TEXT DEFAULT '16:00',
      shift_name TEXT DEFAULT 'Shift Pagi',
      permissions TEXT DEFAULT '',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
    ''',

    // 3. Categories
    '''
    CREATE TABLE IF NOT EXISTS categories (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      display_order INTEGER DEFAULT 0,
      is_active INTEGER DEFAULT 1
    );
    ''',

    // 4. Products
    '''
    CREATE TABLE IF NOT EXISTS products (
      id TEXT PRIMARY KEY,
      category_id TEXT NOT NULL,
      name TEXT NOT NULL,
      description TEXT,
      base_price REAL NOT NULL DEFAULT 0,
      is_active INTEGER DEFAULT 1,
      image_path TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE RESTRICT
    );
    ''',

    // 5. Product Variants (e.g. Small, Medium, Large)
    '''
    CREATE TABLE IF NOT EXISTS product_variants (
      id TEXT PRIMARY KEY,
      product_id TEXT NOT NULL,
      name TEXT NOT NULL,
      price REAL NOT NULL,
      is_default INTEGER DEFAULT 0,
      is_active INTEGER DEFAULT 1,
      FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
    );
    ''',

    // 6. Modifiers (Sugar, Ice, Toppings)
    '''
    CREATE TABLE IF NOT EXISTS modifiers (
      id TEXT PRIMARY KEY,
      group_name TEXT NOT NULL, -- Gula, Es, Topping
      name TEXT NOT NULL, -- Normal, Sedikit, Boba, etc.
      extra_price REAL DEFAULT 0,
      ingredient_id TEXT,
      ingredient_amount REAL DEFAULT 0,
      is_active INTEGER DEFAULT 1,
      FOREIGN KEY (ingredient_id) REFERENCES ingredients (id) ON DELETE SET NULL
    );
    ''',

    // 7. Ingredients & Packaging
    '''
    CREATE TABLE IF NOT EXISTS ingredients (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      unit TEXT NOT NULL, -- gram, ml, pcs, sachet
      current_stock REAL DEFAULT 0,
      minimum_stock REAL DEFAULT 10,
      cost_per_unit REAL DEFAULT 0,
      last_buy_price REAL DEFAULT 0,
      is_packaging INTEGER DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
    ''',

    // 8. Recipes
    '''
    CREATE TABLE IF NOT EXISTS recipes (
      id TEXT PRIMARY KEY,
      product_id TEXT NOT NULL,
      variant_id TEXT,
      name TEXT NOT NULL,
      version INTEGER DEFAULT 1,
      created_at TEXT NOT NULL,
      FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE,
      FOREIGN KEY (variant_id) REFERENCES product_variants (id) ON DELETE CASCADE
    );
    ''',

    // 9. Recipe Items
    '''
    CREATE TABLE IF NOT EXISTS recipe_items (
      id TEXT PRIMARY KEY,
      recipe_id TEXT NOT NULL,
      ingredient_id TEXT NOT NULL,
      amount_required REAL NOT NULL,
      FOREIGN KEY (recipe_id) REFERENCES recipes (id) ON DELETE CASCADE,
      FOREIGN KEY (ingredient_id) REFERENCES ingredients (id) ON DELETE RESTRICT
    );
    ''',

    // 10. Recipe Versions (Audit / Historical)
    '''
    CREATE TABLE IF NOT EXISTS recipe_versions (
      id TEXT PRIMARY KEY,
      recipe_id TEXT NOT NULL,
      version INTEGER NOT NULL,
      snapshot_json TEXT NOT NULL,
      created_at TEXT NOT NULL,
      created_by TEXT,
      FOREIGN KEY (recipe_id) REFERENCES recipes (id) ON DELETE CASCADE
    );
    ''',

    // 11. Purchases
    '''
    CREATE TABLE IF NOT EXISTS purchases (
      id TEXT PRIMARY KEY,
      purchase_number TEXT NOT NULL UNIQUE,
      supplier_name TEXT,
      total_amount REAL NOT NULL,
      payment_method TEXT DEFAULT 'TUNAI',
      purchase_date TEXT NOT NULL,
      notes TEXT,
      created_by TEXT,
      created_at TEXT NOT NULL
    );
    ''',

    // 12. Purchase Items
    '''
    CREATE TABLE IF NOT EXISTS purchase_items (
      id TEXT PRIMARY KEY,
      purchase_id TEXT NOT NULL,
      ingredient_id TEXT NOT NULL,
      quantity REAL NOT NULL,
      unit TEXT NOT NULL,
      unit_price REAL NOT NULL,
      total_price REAL NOT NULL,
      batch_number TEXT,
      expiry_date TEXT,
      FOREIGN KEY (purchase_id) REFERENCES purchases (id) ON DELETE CASCADE,
      FOREIGN KEY (ingredient_id) REFERENCES ingredients (id) ON DELETE RESTRICT
    );
    ''',

    // 13. Stock Batches
    '''
    CREATE TABLE IF NOT EXISTS stock_batches (
      id TEXT PRIMARY KEY,
      ingredient_id TEXT NOT NULL,
      batch_number TEXT,
      initial_quantity REAL NOT NULL,
      remaining_quantity REAL NOT NULL,
      unit_cost REAL NOT NULL,
      expiry_date TEXT,
      received_date TEXT NOT NULL,
      is_active INTEGER DEFAULT 1,
      FOREIGN KEY (ingredient_id) REFERENCES ingredients (id) ON DELETE CASCADE
    );
    ''',

    // 14. Stock Movements (Audit of stock changes)
    '''
    CREATE TABLE IF NOT EXISTS stock_movements (
      id TEXT PRIMARY KEY,
      ingredient_id TEXT NOT NULL,
      batch_id TEXT,
      movement_type TEXT NOT NULL, -- PURCHASE, SALE, ADJUSTMENT, CANCELLATION, WASTE
      quantity_change REAL NOT NULL,
      quantity_before REAL NOT NULL,
      quantity_after REAL NOT NULL,
      reference_id TEXT,
      reason TEXT,
      user_id TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (ingredient_id) REFERENCES ingredients (id) ON DELETE CASCADE,
      FOREIGN KEY (batch_id) REFERENCES stock_batches (id) ON DELETE SET NULL
    );
    ''',

    // 15. Shifts
    '''
    CREATE TABLE IF NOT EXISTS shifts (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      user_name TEXT NOT NULL,
      start_time TEXT NOT NULL,
      end_time TEXT,
      initial_cash REAL NOT NULL DEFAULT 0,
      total_cash_sales REAL DEFAULT 0,
      total_qris_sales REAL DEFAULT 0,
      total_cash_expenses REAL DEFAULT 0,
      expected_cash REAL DEFAULT 0,
      actual_cash REAL,
      cash_difference REAL,
      difference_note TEXT,
      status TEXT DEFAULT 'OPEN', -- OPEN, CLOSED
      FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT
    );
    ''',

    // 16. Transactions
    '''
    CREATE TABLE IF NOT EXISTS transactions (
      id TEXT PRIMARY KEY,
      transaction_number TEXT NOT NULL UNIQUE,
      store_id TEXT,
      shift_id TEXT,
      cashier_id TEXT NOT NULL,
      cashier_name TEXT NOT NULL,
      total_amount REAL NOT NULL,
      discount_amount REAL DEFAULT 0,
      final_amount REAL NOT NULL,
      total_cogs REAL DEFAULT 0, -- HPP snapshot
      gross_profit REAL DEFAULT 0,
      payment_method TEXT NOT NULL, -- TUNAI, QRIS, SPLIT
      cash_received REAL DEFAULT 0,
      qris_amount REAL DEFAULT 0,
      change_amount REAL DEFAULT 0,
      status TEXT DEFAULT 'SELESAI', -- SELESAI, DIBATALKAN
      notes TEXT,
      created_at TEXT NOT NULL,
      cancelled_at TEXT,
      cancelled_by TEXT,
      cancellation_reason TEXT,
      is_restocked INTEGER DEFAULT 0,
      FOREIGN KEY (shift_id) REFERENCES shifts (id) ON DELETE SET NULL,
      FOREIGN KEY (cashier_id) REFERENCES users (id) ON DELETE RESTRICT
    );
    ''',

    // 17. Transaction Items
    '''
    CREATE TABLE IF NOT EXISTS transaction_items (
      id TEXT PRIMARY KEY,
      transaction_id TEXT NOT NULL,
      product_id TEXT NOT NULL,
      product_name TEXT NOT NULL,
      variant_id TEXT,
      variant_name TEXT,
      quantity INTEGER NOT NULL,
      unit_price REAL NOT NULL,
      subtotal REAL NOT NULL,
      unit_cogs REAL DEFAULT 0, -- HPP snapshot per portion
      total_cogs REAL DEFAULT 0,
      notes TEXT,
      recipe_snapshot_json TEXT, -- Historical recipe snapshot
      FOREIGN KEY (transaction_id) REFERENCES transactions (id) ON DELETE CASCADE
    );
    ''',

    // 18. Transaction Modifiers
    '''
    CREATE TABLE IF NOT EXISTS transaction_modifiers (
      id TEXT PRIMARY KEY,
      transaction_item_id TEXT NOT NULL,
      modifier_id TEXT,
      group_name TEXT NOT NULL,
      name TEXT NOT NULL,
      extra_price REAL DEFAULT 0,
      extra_cogs REAL DEFAULT 0,
      FOREIGN KEY (transaction_item_id) REFERENCES transaction_items (id) ON DELETE CASCADE
    );
    ''',

    // 19. Payments
    '''
    CREATE TABLE IF NOT EXISTS payments (
      id TEXT PRIMARY KEY,
      transaction_id TEXT NOT NULL,
      payment_method TEXT NOT NULL,
      amount REAL NOT NULL,
      reference_number TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (transaction_id) REFERENCES transactions (id) ON DELETE CASCADE
    );
    ''',

    // 20. Promotions
    '''
    CREATE TABLE IF NOT EXISTS promotions (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      promo_type TEXT NOT NULL, -- NOMINAL, PERCENTAGE
      discount_value REAL NOT NULL,
      min_purchase REAL DEFAULT 0,
      start_date TEXT,
      end_date TEXT,
      is_active INTEGER DEFAULT 1,
      created_at TEXT NOT NULL
    );
    ''',

    // 21. Expense Categories
    '''
    CREATE TABLE IF NOT EXISTS expense_categories (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      is_system INTEGER DEFAULT 0
    );
    ''',

    // 22. Expenses
    '''
    CREATE TABLE IF NOT EXISTS expenses (
      id TEXT PRIMARY KEY,
      shift_id TEXT,
      category_id TEXT NOT NULL,
      category_name TEXT NOT NULL,
      amount REAL NOT NULL,
      payment_method TEXT DEFAULT 'TUNAI', -- TUNAI, NON_TUNAI
      description TEXT,
      date TEXT NOT NULL,
      created_by TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (shift_id) REFERENCES shifts (id) ON DELETE SET NULL,
      FOREIGN KEY (category_id) REFERENCES expense_categories (id) ON DELETE RESTRICT
    );
    ''',

    // 23. Attendance
    '''
    CREATE TABLE IF NOT EXISTS attendance (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      user_name TEXT NOT NULL,
      date TEXT NOT NULL,
      scheduled_in TEXT DEFAULT '08:00',
      clock_in TEXT,
      clock_out TEXT,
      lateness_minutes INTEGER DEFAULT 0,
      status TEXT DEFAULT 'HADIR', -- HADIR, TERLAMBAT, PULANG_CEPAT, IZIN, ALPA
      notes TEXT,
      photo_path TEXT,
      FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
    );
    ''',

    // 24. Salary Records
    '''
    CREATE TABLE IF NOT EXISTS salary_records (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      user_name TEXT NOT NULL,
      period_month INTEGER NOT NULL,
      period_year INTEGER NOT NULL,
      base_salary REAL NOT NULL,
      bonus REAL DEFAULT 0,
      deductions REAL DEFAULT 0,
      net_salary REAL NOT NULL,
      payment_date TEXT,
      status TEXT DEFAULT 'UNPAID', -- UNPAID, PAID
      notes TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT
    );
    ''',

    // 25. Audit Logs
    '''
    CREATE TABLE IF NOT EXISTS audit_logs (
      id TEXT PRIMARY KEY,
      action TEXT NOT NULL,
      entity_type TEXT NOT NULL,
      entity_id TEXT,
      user_id TEXT,
      user_name TEXT,
      old_value TEXT,
      new_value TEXT,
      reason TEXT,
      created_at TEXT NOT NULL
    );
    ''',

    // 26. App Settings
    '''
    CREATE TABLE IF NOT EXISTS app_settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
    ''',

    // 27. Backup History
    '''
    CREATE TABLE IF NOT EXISTS backup_history (
      id TEXT PRIMARY KEY,
      backup_date TEXT NOT NULL,
      file_name TEXT NOT NULL,
      file_size_bytes INTEGER NOT NULL,
      file_path TEXT NOT NULL,
      backup_type TEXT DEFAULT 'MANUAL',
      status TEXT DEFAULT 'SUCCESS',
      error_message TEXT
    );
    '''
  ];

  static const List<String> createIndicesQueries = [
    'CREATE INDEX IF NOT EXISTS idx_products_category ON products (category_id);',
    'CREATE INDEX IF NOT EXISTS idx_product_variants_product ON product_variants (product_id);',
    'CREATE INDEX IF NOT EXISTS idx_recipes_product ON recipes (product_id);',
    'CREATE INDEX IF NOT EXISTS idx_recipe_items_recipe ON recipe_items (recipe_id);',
    'CREATE INDEX IF NOT EXISTS idx_stock_movements_ingredient ON stock_movements (ingredient_id);',
    'CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions (created_at);',
    'CREATE INDEX IF NOT EXISTS idx_transactions_shift ON transactions (shift_id);',
    'CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions (status);',
    'CREATE INDEX IF NOT EXISTS idx_transaction_items_trx ON transaction_items (transaction_id);',
    'CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses (date);',
    'CREATE INDEX IF NOT EXISTS idx_attendance_user_date ON attendance (user_id, date);',
    'CREATE INDEX IF NOT EXISTS idx_shifts_user_status ON shifts (user_id, status);',
    'CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs (action);'
  ];
}
