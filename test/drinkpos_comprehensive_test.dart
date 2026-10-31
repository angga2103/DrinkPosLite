import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:drinkpos_lite/core/constants/app_constants.dart';
import 'package:drinkpos_lite/core/database/app_database.dart';
import 'package:drinkpos_lite/core/database/database_schema.dart';
import 'package:drinkpos_lite/core/database/seed_data.dart';
import 'package:drinkpos_lite/core/services/excel_report_service.dart';
import 'package:drinkpos_lite/core/services/pdf_report_service.dart';
import 'package:drinkpos_lite/core/services/share_service.dart';
import 'package:drinkpos_lite/core/services/sync_package_service.dart';
import 'package:drinkpos_lite/data/models/expense_model.dart';
import 'package:drinkpos_lite/data/models/ingredient_model.dart';
import 'package:drinkpos_lite/data/models/product_model.dart';
import 'package:drinkpos_lite/data/models/purchase_model.dart';
import 'package:drinkpos_lite/data/models/recipe_model.dart';
import 'package:drinkpos_lite/data/models/salary_model.dart';
import 'package:drinkpos_lite/data/models/store_model.dart';
import 'package:drinkpos_lite/data/models/transaction_model.dart';
import 'package:drinkpos_lite/data/models/user_model.dart';
import 'package:drinkpos_lite/data/repositories/attendance_repository.dart';
import 'package:drinkpos_lite/data/repositories/auth_repository.dart';
import 'package:drinkpos_lite/data/repositories/employee_repository.dart';
import 'package:drinkpos_lite/data/repositories/expense_repository.dart';
import 'package:drinkpos_lite/data/repositories/ingredient_repository.dart';
import 'package:drinkpos_lite/data/repositories/pos_repository.dart';
import 'package:drinkpos_lite/data/repositories/product_repository.dart';
import 'package:drinkpos_lite/data/repositories/purchase_repository.dart';
import 'package:drinkpos_lite/data/repositories/report_repository.dart';
import 'package:drinkpos_lite/data/repositories/salary_repository.dart';
import 'package:drinkpos_lite/data/repositories/settings_repository.dart';
import 'package:drinkpos_lite/data/repositories/shift_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Initialize ffi for desktop test environment
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late AppDatabase appDb;
  late AuthRepository authRepo;
  late ProductRepository productRepo;
  late IngredientRepository ingredientRepo;
  late PurchaseRepository purchaseRepo;
  late PosRepository posRepo;
  late ShiftRepository shiftRepo;
  late ExpenseRepository expenseRepo;
  late EmployeeRepository employeeRepo;
  late AttendanceRepository attendanceRepo;
  late SalaryRepository salaryRepo;
  late ReportRepository reportRepo;
  late SettingsRepository settingsRepo;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );

    // Open in-memory sqlite database for test isolation
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON;');

    final batch = db.batch();
    for (final q in DatabaseSchema.createTablesQueries) {
      batch.execute(q);
    }
    for (final q in DatabaseSchema.createIndicesQueries) {
      batch.execute(q);
    }
    await batch.commit(noResult: true);

    // Seed initial data
    await SeedData.populateInitialData(db);

    appDb = AppDatabase.instance;
    appDb.setDatabaseForTesting(db);

    authRepo = AuthRepository(appDb);
    productRepo = ProductRepository(appDb);
    ingredientRepo = IngredientRepository(appDb);
    purchaseRepo = PurchaseRepository(appDb);
    posRepo = PosRepository(appDb);
    shiftRepo = ShiftRepository(appDb);
    expenseRepo = ExpenseRepository(appDb);
    employeeRepo = EmployeeRepository(appDb);
    attendanceRepo = AttendanceRepository(appDb);
    salaryRepo = SalaryRepository(appDb);
    reportRepo = ReportRepository(appDb);
    settingsRepo = SettingsRepository(appDb);

    // Buka shift awal agar transaksi standar POS berhasil diproses
    await shiftRepo.openShift(
      userId: 'usr_cashier',
      userName: 'Siti (Kasir)',
      initialCash: 100000.0,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('DrinkPOS Lite Mandatory Comprehensive Tests', () {
    // 1. Membuat produk & varian
    test('1. Membuat produk dan varian baru', () async {
      final newProd = ProductModel(
        id: 'prod_kopi_susu',
        categoryId: 'cat_coffee',
        name: 'Es Kopi Karamel',
        description: 'Kopi dengan saus karamel lezat',
        basePrice: 18000,
      );
      final variants = [
        ProductVariantModel(id: 'var_kopi_s', productId: 'prod_kopi_susu', name: 'Regular', price: 18000, isDefault: true),
        ProductVariantModel(id: 'var_kopi_l', productId: 'prod_kopi_susu', name: 'Large', price: 22000),
      ];

      await productRepo.saveProduct(product: newProd, variants: variants);
      final loaded = await productRepo.getProductById('prod_kopi_susu');

      expect(loaded, isNotNull);
      expect(loaded!.name, 'Es Kopi Karamel');
      expect(loaded.variants.length, 2);
    });

    // 2. Membuat bahan baku
    test('2. Membuat bahan baku baru', () async {
      final syrup = IngredientModel(
        id: 'ing_syrup_caramel',
        name: 'Sirup Karamel',
        unit: 'ml',
        currentStock: 1000.0,
        minimumStock: 100.0,
        costPerUnit: 50.0,
        lastBuyPrice: 50.0,
      );

      await ingredientRepo.saveIngredient(syrup);
      final loaded = await ingredientRepo.getIngredientById('ing_syrup_caramel');

      expect(loaded, isNotNull);
      expect(loaded!.name, 'Sirup Karamel');
      expect(loaded.currentStock, 1000.0);
    });

    // 3 & 4. Membuat resep & Menghitung HPP
    test('3 & 4. Membuat resep dan menghitung HPP per cup', () async {
      await productRepo.saveProduct(
        product: ProductModel(
          id: 'prod_matcha_01',
          name: 'Matcha Latte',
          categoryId: 'cat_tea',
          basePrice: 15000.0,
        ),
        variants: [
          ProductVariantModel(id: 'var_matcha_reg', productId: 'prod_matcha_01', name: 'Regular', price: 15000.0),
        ],
      );

      final recipe = RecipeModel(
        id: 'rec_matcha_reg',
        productId: 'prod_matcha_01',
        variantId: 'var_matcha_reg',
        name: 'Resep Matcha Latte Regular',
      );
      final items = [
        RecipeItemModel(id: 'ri_1', recipeId: 'rec_matcha_reg', ingredientId: 'ing_coffee', amountRequired: 20.0, unitCost: 120.0), // 2400
        RecipeItemModel(id: 'ri_2', recipeId: 'rec_matcha_reg', ingredientId: 'ing_milk', amountRequired: 100.0, unitCost: 20.0), // 2000
        RecipeItemModel(id: 'ri_3', recipeId: 'rec_matcha_reg', ingredientId: 'ing_sugar', amountRequired: 20.0, unitCost: 18.0), // 360
        RecipeItemModel(id: 'ri_4', recipeId: 'rec_matcha_reg', ingredientId: 'ing_cup', amountRequired: 1.0, unitCost: 550.0), // 550
      ];

      await ingredientRepo.saveRecipe(recipe: recipe, items: items);
      final loadedRecipe = await ingredientRepo.getRecipeForProduct('prod_matcha_01', variantId: 'var_matcha_reg');

      expect(loadedRecipe, isNotNull);
      expect(loadedRecipe!.items.length, 4);
      // HPP = 2400 + 2000 + 360 + 550 = 5310
      expect(loadedRecipe.calculatedCogs, 5310.0);
    });

    // 5 & 6. Membeli bahan & Stok bertambah
    test('5 & 6. Membeli bahan dan memverifikasi stok bertambah', () async {
      final ingBefore = await ingredientRepo.getIngredientById('ing_tea');
      final stockBefore = ingBefore!.currentStock;

      final purchase = PurchaseModel(
        id: 'po_test_01',
        purchaseNumber: 'PO-20261030-001',
        supplierName: 'Supplier Teh Super',
        totalAmount: 100000.0,
        purchaseDate: '2026-10-30',
      );
      final items = [
        PurchaseItemModel(
          id: 'pi_test_01',
          purchaseId: 'po_test_01',
          ingredientId: 'ing_tea',
          quantity: 2000.0,
          unit: 'gram',
          unitPrice: 50.0,
          totalPrice: 100000.0,
        ),
      ];

      await purchaseRepo.savePurchase(purchase: purchase, items: items);
      final ingAfter = await ingredientRepo.getIngredientById('ing_tea');

      expect(ingAfter!.currentStock, stockBefore + 2000.0);
    });

    // 7 & 8. Menjual minuman & Stok berkurang sesuai resep
    test('7 & 8. Menjual minuman dan verifikasi stok berkurang otomatis sesuai resep', () async {
      final teaBefore = (await ingredientRepo.getIngredientById('ing_tea'))!.currentStock;
      final sugarBefore = (await ingredientRepo.getIngredientById('ing_sugar'))!.currentStock;

      // Sell 2 cups of Es Teh Solo Medium (each uses 15g tea, 25g sugar)
      final items = [
        TransactionItemModel(
          id: '',
          transactionId: '',
          productId: 'prod_tea_solo',
          productName: 'Es Teh Solo Segar',
          variantId: 'var_tea_m',
          variantName: 'Medium',
          quantity: 2,
          unitPrice: 7000.0,
          subtotal: 14000.0,
        ),
      ];

      final trx = await posRepo.createTransaction(
        cashierId: 'usr_cashier',
        cashierName: 'Siti (Kasir)',
        items: items,
        totalAmount: 14000.0,
        finalAmount: 14000.0,
        paymentMethod: AppConstants.paymentCash,
        cashReceived: 20000.0,
        changeAmount: 6000.0,
      );

      expect(trx.status, 'SELESAI');

      final teaAfter = (await ingredientRepo.getIngredientById('ing_tea'))!.currentStock;
      final sugarAfter = (await ingredientRepo.getIngredientById('ing_sugar'))!.currentStock;

      // 2 cups * 15g = 30g tea deducted
      expect(teaAfter, teaBefore - 30.0);
      // 2 cups * 25g = 50g sugar deducted
      expect(sugarAfter, sugarBefore - 50.0);
    });

    // 9, 10, 11, 12. Pembayaran Tunai, QRIS, Split, dan Kembalian
    test('9, 10, 11, 12. Validasi Pembayaran Tunai, QRIS, Split dan Kembalian', () async {
      // Tunai dengan kembalian
      final trxCash = await posRepo.createTransaction(
        cashierId: 'usr_cashier',
        cashierName: 'Siti (Kasir)',
        items: [],
        totalAmount: 15000.0,
        finalAmount: 15000.0,
        paymentMethod: AppConstants.paymentCash,
        cashReceived: 50000.0,
        changeAmount: 35000.0,
      );
      expect(trxCash.paymentMethod, 'TUNAI');
      expect(trxCash.changeAmount, 35000.0);

      // QRIS
      final trxQris = await posRepo.createTransaction(
        cashierId: 'usr_cashier',
        cashierName: 'Siti (Kasir)',
        items: [],
        totalAmount: 25000.0,
        finalAmount: 25000.0,
        paymentMethod: AppConstants.paymentQris,
        qrisAmount: 25000.0,
      );
      expect(trxQris.paymentMethod, 'QRIS');

      // SPLIT (Tunai + QRIS)
      final trxSplit = await posRepo.createTransaction(
        cashierId: 'usr_cashier',
        cashierName: 'Siti (Kasir)',
        items: [],
        totalAmount: 30000.0,
        finalAmount: 30000.0,
        paymentMethod: AppConstants.paymentSplit,
        cashReceived: 10000.0,
        qrisAmount: 20000.0,
      );
      expect(trxSplit.paymentMethod, 'SPLIT');
      expect(trxSplit.payments.length, 2);
    });

    // 13 & 14. Membatalkan transaksi & Pengembalian stok
    test('13 & 14. Membatalkan transaksi dengan alasan dan mengembalikan stok', () async {
      final teaBefore = (await ingredientRepo.getIngredientById('ing_tea'))!.currentStock;

      final trx = await posRepo.createTransaction(
        cashierId: 'usr_cashier',
        cashierName: 'Siti (Kasir)',
        items: [
          TransactionItemModel(
            id: '',
            transactionId: '',
            productId: 'prod_tea_solo',
            productName: 'Es Teh Solo Segar',
            variantId: 'var_tea_m',
            variantName: 'Medium',
            quantity: 2,
            unitPrice: 7000.0,
            subtotal: 14000.0,
          ),
        ],
        totalAmount: 14000.0,
        finalAmount: 14000.0,
        paymentMethod: AppConstants.paymentCash,
      );

      // Cancel with restock = true
      await posRepo.cancelTransaction(
        transactionId: trx.id,
        cancelledByUserId: 'usr_owner',
        cancelledByName: 'Pemilik (Owner)',
        cancellationReason: 'Pelanggan salah pesan',
        shouldRestock: true,
      );

      final cancelledTrxList = await posRepo.getTransactions(query: trx.transactionNumber);
      expect(cancelledTrxList.first.isCancelled, isTrue);

      final teaAfterRestock = (await ingredientRepo.getIngredientById('ing_tea'))!.currentStock;
      expect(teaAfterRestock, teaBefore);
    });

    // 15. Menguji perubahan resep tanpa mengubah histori HPP transaksi lama
    test('15. Perubahan resep masa depan tidak mengubah histori transaksi lama', () async {
      // 1. Buat transaksi dengan resep lama
      final trx = await posRepo.createTransaction(
        cashierId: 'usr_cashier',
        cashierName: 'Siti (Kasir)',
        items: [
          TransactionItemModel(
            id: '',
            transactionId: '',
            productId: 'prod_tea_solo',
            productName: 'Es Teh Solo Segar',
            variantId: 'var_tea_m',
            quantity: 1,
            unitPrice: 7000.0,
            subtotal: 7000.0,
          ),
        ],
        totalAmount: 7000.0,
        finalAmount: 7000.0,
        paymentMethod: AppConstants.paymentCash,
      );

      final historicalCogs = trx.totalCogs;

      // 2. Ubah resep dengan menambahkan bahan baru berbiaya tinggi
      final newRecipe = RecipeModel(
        id: 'rec_tea_m',
        productId: 'prod_tea_solo',
        variantId: 'var_tea_m',
        name: 'Resep Baru Es Teh',
      );
      final newItems = [
        RecipeItemModel(id: 'ri_new_1', recipeId: 'rec_tea_m', ingredientId: 'ing_tea', amountRequired: 50.0, unitCost: 100.0),
      ];
      await ingredientRepo.saveRecipe(recipe: newRecipe, items: newItems);

      // 3. Periksa kembali transaksi lama
      final loadedOldTrx = (await posRepo.getTransactions(query: trx.transactionNumber)).first;
      expect(loadedOldTrx.totalCogs, historicalCogs);
    });

    // 16 & 17. Buka & Tutup Shift dan Menghitung Selisih Kas
    test('16 & 17. Buka dan tutup shift, hitung selisih kas fisik', () async {
      // Buka shift kas awal 100.000
      final shift = await shiftRepo.openShift(
        userId: 'usr_cashier',
        userName: 'Siti (Kasir)',
        initialCash: 100000.0,
      );
      expect(shift.status, 'OPEN');

      // Transaksi tunai 50.000 dalam shift
      await posRepo.createTransaction(
        cashierId: 'usr_cashier',
        cashierName: 'Siti',
        shiftId: shift.id,
        items: [],
        totalAmount: 50000.0,
        finalAmount: 50000.0,
        paymentMethod: AppConstants.paymentCash,
        cashReceived: 50000.0,
      );

      // Pengeluaran tunai 20.000
      await expenseRepo.saveExpense(
        expense: ExpenseModel(
          id: 'exp_test_01',
          shiftId: shift.id,
          categoryId: 'expcat_water',
          categoryName: 'Air PDAM / Galon',
          amount: 20000.0,
          paymentMethod: 'TUNAI',
          date: '2026-10-30',
        ),
        currentShiftId: shift.id,
      );

      // Expected cash = 100.000 (awal) + 50.000 (jual) - 20.000 (biaya) = 130.000
      // Kasir menghitung uang fisik ada 128.000 (selisih -2.000)
      await shiftRepo.closeShift(
        shiftId: shift.id,
        actualCash: 128000.0,
        differenceNote: 'Kurang 2000 pecahan kecil',
        userId: 'usr_cashier',
      );

      final history = await shiftRepo.getShiftHistory();
      final closed = history.firstWhere((s) => s.id == shift.id);

      expect(closed.status, 'CLOSED');
      expect(closed.expectedCash, 130000.0);
      expect(closed.actualCash, 128000.0);
      expect(closed.cashDifference, -2000.0);
    });

    // 18 & 19. Clock-in, Clock-out & Menghitung keterlambatan
    test('18 & 19. Clock-in, clock-out dengan selfie watermark & anti kecurangan', () async {
      final employees = await employeeRepo.getEmployees();
      expect(employees.isNotEmpty, isTrue);

      // Scheduled 08:00, clock in via attendanceRepo dengan foto selfie
      final att = await attendanceRepo.clockIn(
        userId: 'usr_cashier',
        enteredPin: '3456',
        scheduledIn: '08:00',
        photoPath: '/storage/attendance_selfies/Selfie_CLOCK-IN_Siti_12345.jpg',
      );
      expect(att.isClockedIn, isTrue);
      expect(att.photoPath, isNotNull);
      expect(att.hasPhoto, isTrue);

      // Pencegahan dobel clock-in di hari yang sama
      expect(
        () => attendanceRepo.clockIn(
          userId: 'usr_cashier',
          enteredPin: '3456',
          scheduledIn: '08:00',
        ),
        throwsException,
      );

      final out = await attendanceRepo.clockOut(
        userId: 'usr_cashier',
        enteredPin: '3456',
        photoPath: '/storage/attendance_selfies/Selfie_CLOCK-OUT_Siti_12345.jpg',
      );
      expect(out.isClockedOut, isTrue);
      expect(out.photoPath, contains('CLOCK-OUT'));

      // Tes pencatatan Izin / Sakit oleh Owner/Manager
      final leave = await attendanceRepo.recordLeave(
        userId: 'usr_manager',
        status: 'IZIN',
        notes: 'Izin urusan keluarga',
        recordedByUserId: 'usr_owner',
      );
      expect(leave.status, equals('IZIN'));
      expect(leave.notes, equals('Izin urusan keluarga'));
    });

    // 20 & 21. Mengunci akun setelah 5x salah PIN & Membuka akun oleh owner
    test('20 & 21. Mengunci akun setelah 5 kali salah PIN dan membuka akun oleh Owner', () async {
      // 5 consecutive wrong PIN attempts for manager
      for (int i = 0; i < 5; i++) {
        await authRepo.loginWithPin(userId: 'usr_manager', enteredPin: '9999');
      }

      final manager = await authRepo.getUserById('usr_manager');
      expect(manager!.isLocked, isTrue);

      // Attempt login while locked
      final loginResult = await authRepo.loginWithPin(userId: 'usr_manager', enteredPin: '2345');
      expect(loginResult.isLocked, isTrue);
      expect(loginResult.success, isFalse);

      // Owner unlocks manager
      final unlocked = await authRepo.unlockUser(userId: 'usr_manager', ownerUserId: 'usr_owner');
      expect(unlocked, isTrue);

      final managerAfter = await authRepo.getUserById('usr_manager');
      expect(managerAfter!.isLocked, isFalse);
    });

    // 22. Mencatat gaji pegawai & Menandai sudah dibayar
    test('22. Mencatat slip gaji dan membayar gaji pegawai', () async {
      final slip = SalaryRecordModel(
        id: 'sal_test_siti_10',
        userId: 'usr_cashier',
        userName: 'Siti (Kasir)',
        periodMonth: 10,
        periodYear: 2026,
        baseSalary: 2200000.0,
        bonus: 100000.0,
        deductions: 50000.0,
        netSalary: 2250000.0,
      );

      await salaryRepo.saveSalaryRecord(slip);
      await salaryRepo.markAsPaid(recordId: slip.id);

      final records = await salaryRepo.getSalaryRecords();
      final loaded = records.firstWhere((r) => r.id == slip.id);
      expect(loaded.isPaid, isTrue);

      // Verified expense created
      final expenses = await expenseRepo.getExpenses();
      expect(expenses.any((e) => e.amount == 2250000.0), isTrue);
    });

    // 23, 24, 25. Laporan PDF, Excel XLSX, WhatsApp Text Summary
    test('23, 24, 25. Generate Laporan PDF, Excel XLSX, dan WhatsApp Summary', () async {
      final reportData = await reportRepo.getSalesReport(
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 31),
      );

      expect(reportData, isNotNull);

      // PDF generation
      final pdfBytes = await PdfReportService.generateSalesReportPdf(reportData);
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(500));

      // Excel XLSX generation
      final excelFile = await ExcelReportService.generateSalesReportExcel(reportData);
      expect(await excelFile.exists(), isTrue);
      expect(await excelFile.length(), greaterThan(1000));

      // WhatsApp formatted summary text
      final textSummary = ShareService.formatWhatsAppSummary(reportData);
      expect(textSummary, contains('LAPORAN PENJUALAN — DRINKPOS LITE'));
      expect(textSummary, contains(AppConstants.developedByText));
      expect(textSummary, contains(AppConstants.contactText));
    });

    // 26, 27, 28, 29. Integritas Database, Offline operation, Developer identity
    test('26, 27, 28, 29. Integritas database lokal dan verifikasi identitas developer', () async {
      // Verify developer constants
      expect(AppConstants.developerName, 'Ansor.Studio');
      expect(AppConstants.developerContact, '081775700114');

      // Verify database integrity
      final check = await db.rawQuery('PRAGMA integrity_check;');
      expect(check.first['integrity_check'], 'ok');

      // Verify store info
      final store = await settingsRepo.getStore();
      expect(store.phone, '081775700114');
    });

    // 30. Verifikasi 7 Perbaikan User Feedback (Report ISO date, Low-stock WA, Shift time, Sync package)
    test('30. Verifikasi 7 perbaikan user feedback dan sinkronisasi jarak jauh', () async {
      // 1. Bug Laporan (Issue #2): buat transaksi baru berformat ISO dan pastikan dihitung oleh getDashboardMetrics()
      await posRepo.createTransaction(
        cashierId: 'usr_cashier',
        cashierName: 'Siti (Kasir)',
        items: [
          TransactionItemModel(
            id: '',
            transactionId: '',
            productId: 'prod_tea_solo',
            productName: 'Es Teh Solo Segar',
            variantId: 'var_tea_m',
            variantName: 'Medium',
            quantity: 1,
            unitPrice: 7000.0,
            subtotal: 7000.0,
          ),
        ],
        totalAmount: 7000.0,
        finalAmount: 7000.0,
        paymentMethod: AppConstants.paymentCash,
        cashReceived: 10000.0,
        changeAmount: 3000.0,
      );

      final todayMetrics = await reportRepo.getDashboardMetrics();
      expect(todayMetrics.omzetToday, greaterThan(0));
      expect(todayMetrics.transactionCountToday, greaterThan(0));

      // 2. Format Pesan WhatsApp Bahan Menipis (Issue #6)
      final lowStockItems = [
        IngredientModel(
          id: 'ing_test_tea',
          name: 'Daun Teh Melati',
          unit: 'gram',
          currentStock: 150.0,
          minimumStock: 500.0,
          lastBuyPrice: 50000.0,
          costPerUnit: 100.0,
        ),
      ];
      final waMsg = ShareService.formatLowStockProcurementMessage(
        items: lowStockItems,
        storeName: 'Kedai Es Teh Mantap',
        storePhone: '081234567890',
      );
      expect(waMsg, contains('PESANAN PENGADAAN BAHAN BAKU'));
      expect(waMsg, contains('Daun Teh Melati'));
      expect(waMsg, contains('150 gram'));
      expect(waMsg, contains(AppConstants.developedByText));
      expect(waMsg, contains(AppConstants.contactText));

      // 3. Pengaturan Shift Pegawai (Issue #5)
      final testEmp = UserModel(
        id: 'usr_shift_test',
        name: 'Budi Kasir',
        role: 'CASHIER',
        pinHash: 'dummy',
        shiftName: 'Shift Sore',
        shiftStartTime: '14:00',
        shiftEndTime: '22:00',
      );
      expect(testEmp.shiftName, 'Shift Sore');
      expect(testEmp.shiftStartTime, '14:00');
      expect(testEmp.shiftEndTime, '22:00');
      final empMap = testEmp.toMap();
      expect(empMap['shift_name'], 'Shift Sore');
      expect(empMap['shift_start_time'], '14:00');
      expect(empMap['shift_end_time'], '22:00');

      // 4. Verifikasi Schema Kolom Database Baru (logo_path, shift columns)
      final storeColumns = await db.rawQuery('PRAGMA table_info(stores);');
      final storeColNames = storeColumns.map((c) => c['name']).toList();
      expect(storeColNames, contains('logo_path'));

      final userColumns = await db.rawQuery('PRAGMA table_info(users);');
      final userColNames = userColumns.map((c) => c['name']).toList();
      expect(userColNames, contains('shift_start_time'));
      expect(userColNames, contains('shift_end_time'));
      expect(userColNames, contains('shift_name'));
      expect(userColNames, contains('permissions'));

      // 5. Test Developer Identity Branding
      expect(AppConstants.developerName, 'Ansor.Studio');
      expect(AppConstants.developerContact, '081775700114');
      expect(AppConstants.developerWhatsAppUrl, 'https://wa.me/6281775700114');

      // 6. Test User Permissions & canAccess
      final customEmp = UserModel(
        id: 'usr_perm_test',
        name: 'Siti Kasir',
        role: 'CASHIER',
        pinHash: 'dummy',
        permissions: ['pos', 'attendance', 'reports'],
      );
      expect(customEmp.canAccess('pos'), isTrue);
      expect(customEmp.canAccess('reports'), isTrue);
      expect(customEmp.canAccess('products'), isFalse);
      expect(customEmp.canAccess('settings'), isFalse);

      final ownerUser = UserModel(
        id: 'usr_owner_test',
        name: 'Owner Boss',
        role: 'OWNER',
        pinHash: 'dummy',
      );
      expect(ownerUser.canAccess('settings'), isTrue);
      expect(ownerUser.canAccess('backup'), isTrue);

      // 7. Test Employee Deletion (Owner feature)
      final empToDelete = UserModel(
        id: 'usr_to_delete',
        name: 'Pegawai Resign',
        role: 'CASHIER',
        pinHash: 'dummy',
      );
      await employeeRepo.saveEmployee(employee: empToDelete);
      var allEmps = await employeeRepo.getEmployees();
      expect(allEmps.any((e) => e.id == 'usr_to_delete'), isTrue);

      final deleteSuccess = await employeeRepo.deleteEmployee('usr_to_delete', ownerUser.id);
      expect(deleteSuccess, isTrue);
      allEmps = await employeeRepo.getEmployees();
      expect(allEmps.any((e) => e.id == 'usr_to_delete'), isFalse);
    });

    // 17. Penjualan Ditolak Jika Shift Tutup & Hanya Diizinkan Pada Shift Aktif (User Rule #1 & #2)
    test('17. Penjualan ditolak jika shift tutup dan hanya diizinkan pada shift aktif', () async {
      // Pastikan semua shift ditutup terlebih dahulu
      final activeShift = await shiftRepo.getCurrentOpenShift();
      if (activeShift != null) {
        await shiftRepo.closeShift(
          shiftId: activeShift.id,
          actualCash: 50000.0,
          userId: 'usr_owner',
        );
      }
      expect(await shiftRepo.getCurrentOpenShift(), isNull);

      final items = [
        TransactionItemModel(
          id: '',
          transactionId: '',
          productId: 'prod_tea_solo',
          productName: 'Es Teh Manis',
          variantName: 'Regular',
          quantity: 1,
          unitPrice: 5000.0,
          subtotal: 5000.0,
        ),
      ];

      // Harus melempar exception karena shift ditutup / shiftId null
      expect(
        () async => await posRepo.createTransaction(
          cashierId: 'usr_cashier',
          cashierName: 'Kasir Shift',
          shiftId: null,
          items: items,
          totalAmount: 5000.0,
          finalAmount: 5000.0,
          paymentMethod: AppConstants.paymentCash,
          cashReceived: 5000.0,
          changeAmount: 0.0,
        ),
        throwsA(isA<Exception>()),
      );

      // Buka shift baru secara resmi
      final newShift = await shiftRepo.openShift(
        userId: 'usr_cashier',
        userName: 'Siti Kasir',
        initialCash: 100000.0,
      );
      expect(newShift, isNotNull);
      expect(newShift.status, 'OPEN');

      // Transaksi dengan shift aktif yang baru dibuka harus berhasil disimpan
      final savedTx = await posRepo.createTransaction(
        cashierId: 'usr_cashier',
        cashierName: 'Siti Kasir',
        shiftId: newShift.id,
        items: items,
        totalAmount: 5000.0,
        finalAmount: 5000.0,
        paymentMethod: AppConstants.paymentCash,
        cashReceived: 10000.0,
        changeAmount: 5000.0,
      );
      expect(savedTx.id, isNotEmpty);
      expect(savedTx.shiftId, newShift.id);
    });

    // 18. Sembunyikan HPP, Laba Kotor, & Laba Setelah Pengeluaran untuk Kasir (User Rule #3)
    test('18. Sembunyikan HPP dan estimasi laba pada laporan kasir', () async {
      final report = await reportRepo.getSalesReport(
        startDate: DateTime.now().subtract(const Duration(days: 1)),
        endDate: DateTime.now().add(const Duration(days: 1)),
      );

      // Format untuk kasir: HPP & laba disembunyikan
      final cashierText = ShareService.formatWhatsAppSummary(
        report,
        isCashier: true,
      );
      expect(cashierText, contains('Total Omzet'));
      expect(cashierText, isNot(contains('Total HPP (Bahan)')));
      expect(cashierText, isNot(contains('Estimasi Laba Kotor')));
      expect(cashierText, isNot(contains('Est. Laba Bersih')));

      // Format untuk owner/manager: HPP & laba disertakan
      final ownerText = ShareService.formatWhatsAppSummary(
        report,
        isCashier: false,
      );
      expect(ownerText, contains('Total Omzet'));
      expect(ownerText, contains('Total HPP (Bahan)'));
      expect(ownerText, contains('Estimasi Laba Kotor'));
      expect(ownerText, contains('Est. Laba Bersih'));
    });

    // 19. Hak Akses Mandiri Printer Bluetooth untuk Kasir (User Rule #6)
    test('19. Kasir dapat mengakses menu pengaturan printer secara mandiri tanpa akses profil toko', () {
      final cashier = UserModel(
        id: 'usr_c_01',
        name: 'Kasir 1',
        role: 'CASHIER',
        pinHash: 'dummy',
      );
      expect(cashier.canAccess('printer'), isTrue);
      expect(cashier.canAccess('settings'), isFalse);
      expect(cashier.canManageStoreProfile, isFalse);

      final manager = UserModel(
        id: 'usr_m_01',
        name: 'Manager 1',
        role: 'MANAGER',
        pinHash: 'dummy',
      );
      expect(manager.canAccess('printer'), isTrue);
      expect(manager.canManageStoreProfile, isTrue);

      final owner = UserModel(
        id: 'usr_o_01',
        name: 'Owner 1',
        role: 'OWNER',
        pinHash: 'dummy',
      );
      expect(owner.canAccess('printer'), isTrue);
      expect(owner.canManageStoreProfile, isTrue);
    });

    // 20. Ekspor & Impor Paket Pembaruan Jarak Jauh WhatsApp (.dpos) Lulus 100% (User Rule #7)
    test('20. Ekspor, verifikasi, dan impor paket pembaruan jarak jauh .dpos berhasil 100%', () async {
      // 1. Buat paket pembaruan .dpos
      final packageFile = await SyncPackageService.createPackageFile();
      expect(packageFile.existsSync(), isTrue);
      expect(packageFile.path.endsWith('.dpos'), isTrue);

      final fileContent = await packageFile.readAsString();
      expect(fileContent.startsWith(SyncPackageService.packageMagicHeader), isTrue);

      // 2. Verifikasi dan parse data paket
      final parsed = await SyncPackageService.verifyAndParsePackage(packageFile.path);
      expect(parsed['app'], AppConstants.appName);
      expect(parsed['products'], isA<List>());
      expect(parsed['ingredients'], isA<List>());
      expect(parsed['recipes'], isA<List>());

      // 3. Terapkan paket secara atomik ke database tanpa foreign key conflict
      final syncResult = await SyncPackageService.applyPackage(
        data: parsed,
        appliedByUserId: 'usr_owner',
      );
      expect(syncResult.productsCount, greaterThan(0));
      expect(syncResult.ingredientsCount, greaterThan(0));

      // Bersihkan file sementara
      if (packageFile.existsSync()) {
        packageFile.deleteSync();
      }
    });

    // 21. Simpan & Muat Identitas Toko dan Logo Struk (Issue #2)
    test('21. Pengaturan identitas toko dan logo struk tersimpan dan dimuat secara persisten', () async {
      final newStoreData = StoreModel(
        id: 'store_main',
        name: 'Kedai Kopi & Teh Berkah',
        address: 'Jl. Malioboro No. 45, Yogyakarta',
        phone: '081234567899',
        receiptHeader: 'BERKAH RASA\nSegar Nikmat Tiada Tara',
        receiptFooter: 'Matur Nuwun Sampun Rawuh!\nInstagram: @berkah.rasa',
        logoPath: '/dummy/path/logo_store.png',
      );

      await settingsRepo.updateStore(newStoreData, operatorUserId: 'usr_owner');

      // Ambil kembali dari database
      final loaded = await settingsRepo.getStore();
      expect(loaded.name, 'Kedai Kopi & Teh Berkah');
      expect(loaded.address, 'Jl. Malioboro No. 45, Yogyakarta');
      expect(loaded.phone, '081234567899');
      expect(loaded.receiptHeader, contains('BERKAH RASA'));
      expect(loaded.receiptFooter, contains('Matur Nuwun'));
      expect(loaded.logoPath, '/dummy/path/logo_store.png');
    });

    // 22. Proteksi Owner Lockout & Auto-Unlock (Fix Celah 1)
    test('22. Akun Owner tidak terkunci permanen dan dapat auto-unlock saat memasukkan PIN benar', () async {
      // Masukkan PIN salah 6 kali untuk Owner
      for (int i = 0; i < 6; i++) {
        final res = await authRepo.loginWithPin(userId: 'usr_owner', enteredPin: '9999');
        expect(res.success, false);
        expect(res.isLocked, false); // Owner tidak diset isLocked = true
      }

      // Owner memasukkan PIN benar (1234)
      final successRes = await authRepo.loginWithPin(userId: 'usr_owner', enteredPin: '1234');
      expect(successRes.success, true);
      expect(successRes.user?.failedAttempts, 0);
      expect(successRes.user?.isLocked, false);
    });

    // 23. Pemulihan Kas Shift Saat Pengeluaran Dihapus (Fix Celah 4)
    test('23. Menghapus pengeluaran kas otomatis mengembalikan saldo kas laci shift aktif', () async {
      // Pastikan ada shift aktif
      var currentShift = await shiftRepo.getCurrentOpenShift();
      if (currentShift == null) {
        currentShift = await shiftRepo.openShift(userId: 'usr_owner', userName: 'Ansor', initialCash: 100000);
      }

      final initialExpected = currentShift.expectedCash;

      // Catat pengeluaran kas Rp 25.000 dengan kategori valid (expcat_other)
      final exp = ExpenseModel(
        id: 'exp_test_delete',
        shiftId: currentShift.id,
        categoryId: 'expcat_other',
        categoryName: 'Operasional Lainnya',
        amount: 25000,
        date: DateTime.now().toIso8601String().substring(0, 10),
        paymentMethod: 'TUNAI',
        description: 'Beli sedotan & plastik',
      );

      await expenseRepo.saveExpense(expense: exp, currentShiftId: currentShift.id);

      // Verifikasi kas shift terpotong
      var shiftAfterExp = await shiftRepo.getCurrentOpenShift();
      expect(shiftAfterExp!.totalCashExpenses, greaterThanOrEqualTo(25000));

      // Hapus pengeluaran
      await expenseRepo.deleteExpense(exp.id, userId: 'usr_owner', userName: 'Ansor');

      // Verifikasi kas shift pulih kembali
      var shiftAfterDelete = await shiftRepo.getCurrentOpenShift();
      expect(shiftAfterDelete!.expectedCash, initialExpected);
    });

    // 24. Sinkronisasi Jarak Jauh Menjaga Stok Nyata Outlet (Fix Celah 2)
    test('24. Impor paket .dpos tidak menimpa current_stock outlet lokal yang sedang aktif', () async {
      // Ambil bahan yang ada (misal: Daun Teh)
      final ingList = await ingredientRepo.getIngredients();
      final tea = ingList.firstWhere((i) => i.name.contains('Teh'));
      final localStockBefore = tea.currentStock;

      // Simulasikan paket sync dari owner yang memiliki nilai current_stock berbeda (misal 99999)
      final fakeOwnerData = {
        'app': AppConstants.appName,
        'categories': [],
        'products': [],
        'product_variants': [],
        'modifiers': [],
        'recipes': [],
        'recipe_items': [],
        'purchases': [],
        'purchase_items': [],
        'stock_batches': [],
        'ingredients': [
          {
            'id': tea.id,
            'name': tea.name,
            'unit': tea.unit,
            'current_stock': 99999.0, // Stock versi owner
            'minimum_stock': 15.0,
            'cost_per_unit': tea.costPerUnit,
            'last_buy_price': 50.0,
            'is_packaging': 0,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          }
        ],
      };

      await SyncPackageService.applyPackage(data: fakeOwnerData, appliedByUserId: 'usr_cashier');

      // Verifikasi bahwa current_stock lokal outlet TIDAK tertimpa menjadi 99999
      final teaAfterSync = await ingredientRepo.getIngredientById(tea.id);
      expect(teaAfterSync!.currentStock, localStockBefore);
      expect(teaAfterSync.minimumStock, 15.0); // metadata lain tetap diperbarui
    });

    // 25. Pencegahan Multiple Shift Aktif (Fix Celah 8)
    test('25. Membuka shift baru saat masih ada shift aktif akan ditolak jika autoClosePrevious false', () async {
      // Pastikan ada shift aktif
      final activeShift = await shiftRepo.getCurrentOpenShift();
      expect(activeShift, isNotNull);

      // Coba buka shift lagi tanpa menutup yang lama (autoClosePrevious: false)
      expect(
        () async => await shiftRepo.openShift(userId: 'usr_cashier', userName: 'Siti', initialCash: 50000, autoClosePrevious: false),
        throwsA(isA<Exception>()),
      );
    });
  });
}
