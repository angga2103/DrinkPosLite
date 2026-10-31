import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../database/app_database.dart';
import '../security/audit_logger.dart';
import '../utils/date_formatter.dart';

class SyncPackageResult {
  final bool success;
  final String message;
  final int productsCount;
  final int ingredientsCount;
  final int recipesCount;
  final int purchasesCount;
  final int batchesCount;

  SyncPackageResult({
    required this.success,
    required this.message,
    this.productsCount = 0,
    this.ingredientsCount = 0,
    this.recipesCount = 0,
    this.purchasesCount = 0,
    this.batchesCount = 0,
  });
}

class SyncPackageService {
  static const String secretKey = 'drinkpos_sync_secure_salt_2026';
  static const String headerPrefix = 'DPOS_V1';
  static String get packageMagicHeader => '$headerPrefix#';

  /// 1. Owner generates encrypted update package and shares directly to WhatsApp
  static Future<File> createPackageFile() async {
    final db = await AppDatabase.instance.database;

    // Fetch master data to sync
    final categories = await db.query('categories');
    final products = await db.query('products');
    final variants = await db.query('product_variants');
    final ingredients = await db.query('ingredients');
    final modifiers = await db.query('modifiers');

    // Recipes & matching Recipe Items
    final recipes = await db.query('recipes');
    final recipeIds = recipes.map((r) => r['id'] as String).toList();
    List<Map<String, dynamic>> recipeItems = [];
    if (recipeIds.isNotEmpty) {
      final placeholders = List.filled(recipeIds.length, '?').join(',');
      recipeItems = await db.rawQuery(
        'SELECT * FROM recipe_items WHERE recipe_id IN ($placeholders)',
        recipeIds,
      );
    } else {
      recipeItems = await db.query('recipe_items');
    }

    // Purchases & matching Purchase Items
    final purchases = await db.query('purchases', orderBy: 'purchase_date DESC', limit: 100);
    final purchaseIds = purchases.map((p) => p['id'] as String).toList();

    List<Map<String, dynamic>> purchaseItems = [];
    if (purchaseIds.isNotEmpty) {
      final placeholders = List.filled(purchaseIds.length, '?').join(',');
      purchaseItems = await db.rawQuery(
        'SELECT * FROM purchase_items WHERE purchase_id IN ($placeholders)',
        purchaseIds,
      );
    } else {
      purchaseItems = await db.query('purchase_items');
    }

    // Stock Batches for ingredients (stock_batches has ingredient_id, NOT purchase_id)
    final stockBatches = await db.query('stock_batches');

    final payload = {
      'app': AppConstants.appName,
      'version': '1.0',
      'created_at': DateTime.now().toIso8601String(),
      'categories': categories,
      'products': products,
      'product_variants': variants,
      'ingredients': ingredients,
      'recipes': recipes,
      'recipe_items': recipeItems,
      'modifiers': modifiers,
      'purchases': purchases,
      'purchase_items': purchaseItems,
      'stock_batches': stockBatches,
    };

    final jsonStr = jsonEncode(payload);

    // Compute cryptographic HMAC-SHA256 signature
    final hmac = Hmac(sha256, utf8.encode(secretKey));
    final signature = hmac.convert(utf8.encode(jsonStr)).toString();

    // Obfuscate with Base64 envelope
    final base64Payload = base64Encode(utf8.encode(jsonStr));
    final fileContent = '$headerPrefix#$signature#$base64Payload';

    final tempDir = await getTemporaryDirectory();
    final fileName = 'DrinkPOS_Update_${DateFormatter.forFileName(DateTime.now())}.dpos';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(fileContent, flush: true);
    return file;
  }

  /// Share the package file via WhatsApp / Android Share Sheet
  static Future<void> sharePackageToWhatsApp() async {
    final file = await createPackageFile();
    final fileName = file.path.split(Platform.pathSeparator).last;
    const shareText = 'Halo tim kasir DrinkPOS Lite,\n\n'
        'Berikut berkas pembaruan resep racikan, menu produk, dan stok bahan baku terbaru dari Owner.\n\n'
        'Cara update di HP kasir:\n'
        '1. Klik file lampiran ini (.dpos) di WhatsApp dan pilih "DrinkPOS Lite"\n'
        '2. Atau buka menu Stok / Pengaturan -> "Impor Paket Update"\n'
        '3. Klik "Terapkan Sekarang".\n\n'
        'Pembaruan otomatis selesai dalam hitungan detik tanpa menghapus histori penjualan Anda!';

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/octet-stream', name: fileName)],
      text: shareText,
      subject: 'Paket Update Resep & Stok DrinkPOS Lite',
    );
  }

  /// 2. Parse and verify package before applying
  static Future<Map<String, dynamic>> verifyAndParsePackage(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Berkas pembaruan tidak ditemukan: $filePath');
    }

    final rawContent = await file.readAsString();
    final content = rawContent.trim();

    final firstHash = content.indexOf('#');
    final secondHash = firstHash != -1 ? content.indexOf('#', firstHash + 1) : -1;

    if (firstHash == -1 || secondHash == -1) {
      throw Exception('Format berkas tidak valid atau bukan berkas DrinkPOS Update (.dpos)');
    }

    final prefix = content.substring(0, firstHash).trim();
    if (prefix != headerPrefix) {
      throw Exception('Versi paket pembaruan tidak cocok ($prefix != $headerPrefix)');
    }

    final signature = content.substring(firstHash + 1, secondHash).trim();
    final base64Payload = content.substring(secondHash + 1).replaceAll(RegExp(r'\s+'), '');

    final decodedBytes = base64Decode(base64Payload);
    final jsonStr = utf8.decode(decodedBytes);

    // Verify cryptographic HMAC-SHA256 signature
    final hmac = Hmac(sha256, utf8.encode(secretKey));
    final expectedSignature = hmac.convert(utf8.encode(jsonStr)).toString();

    if (signature.toLowerCase() != expectedSignature.toLowerCase()) {
      throw Exception('Verifikasi keamanan gagal! Berkas pembaruan telah dimodifikasi atau rusak.');
    }

    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    return data;
  }

  /// 3. Apply package atomically to SQLite database
  static Future<SyncPackageResult> applyPackage({
    required Map<String, dynamic> data,
    required String appliedByUserId,
  }) async {
    final db = await AppDatabase.instance.database;

    int productsCount = 0;
    int ingredientsCount = 0;
    int recipesCount = 0;
    int purchasesCount = 0;
    int batchesCount = 0;

    // Temporarily disable foreign keys during sync to avoid cascade deletion or ordering issues
    await db.execute('PRAGMA foreign_keys = OFF;');
    try {
      await db.transaction((txn) async {
        // 1. Categories
        final categories = (data['categories'] as List? ?? []);
        for (final c in categories) {
          await txn.insert('categories', Map<String, dynamic>.from(c), conflictAlgorithm: ConflictAlgorithm.replace);
        }

        // 2. Ingredients (Stok & Bahan Baku)
        final ingredients = (data['ingredients'] as List? ?? []);
        ingredientsCount = ingredients.length;
        for (final ing in ingredients) {
          await txn.insert('ingredients', Map<String, dynamic>.from(ing), conflictAlgorithm: ConflictAlgorithm.replace);
        }

        // 3. Products
        final products = (data['products'] as List? ?? []);
        productsCount = products.length;
        for (final p in products) {
          await txn.insert('products', Map<String, dynamic>.from(p), conflictAlgorithm: ConflictAlgorithm.replace);
        }

        // 4. Product Variants
        final variants = (data['product_variants'] as List? ?? []);
        for (final v in variants) {
          await txn.insert('product_variants', Map<String, dynamic>.from(v), conflictAlgorithm: ConflictAlgorithm.replace);
        }

        // 5. Modifiers
        final modifiers = (data['modifiers'] as List? ?? []);
        for (final m in modifiers) {
          await txn.insert('modifiers', Map<String, dynamic>.from(m), conflictAlgorithm: ConflictAlgorithm.replace);
        }

        // 6. Recipes & Items
        final recipes = (data['recipes'] as List? ?? []);
        recipesCount = recipes.length;
        for (final r in recipes) {
          await txn.insert('recipes', Map<String, dynamic>.from(r), conflictAlgorithm: ConflictAlgorithm.replace);
        }

        final recipeItems = (data['recipe_items'] as List? ?? []);
        for (final ri in recipeItems) {
          await txn.insert('recipe_items', Map<String, dynamic>.from(ri), conflictAlgorithm: ConflictAlgorithm.replace);
        }

        // 7. Purchases & Items
        final purchases = (data['purchases'] as List? ?? []);
        purchasesCount = purchases.length;
        for (final po in purchases) {
          await txn.insert('purchases', Map<String, dynamic>.from(po), conflictAlgorithm: ConflictAlgorithm.replace);
        }

        final purchaseItems = (data['purchase_items'] as List? ?? []);
        for (final poi in purchaseItems) {
          await txn.insert('purchase_items', Map<String, dynamic>.from(poi), conflictAlgorithm: ConflictAlgorithm.replace);
        }

        // 8. Stock Batches
        final batches = (data['stock_batches'] as List? ?? []);
        batchesCount = batches.length;
        for (final b in batches) {
          await txn.insert('stock_batches', Map<String, dynamic>.from(b), conflictAlgorithm: ConflictAlgorithm.replace);
        }

        // 9. Audit Log
        await AuditLogger.log(
          action: 'SYNC_PACKAGE_APPLIED',
          entityType: 'SYSTEM',
          entityId: 'IMPORT',
          userId: appliedByUserId,
          reason: 'Impor pembaruan resep & stok dari Owner ($productsCount produk, $ingredientsCount bahan, $recipesCount resep, $purchasesCount pembelian)',
          db: txn,
        );
      });
    } finally {
      await db.execute('PRAGMA foreign_keys = ON;');
    }

    return SyncPackageResult(
      success: true,
      message: 'Pembaruan berhasil diterapkan!',
      productsCount: productsCount,
      ingredientsCount: ingredientsCount,
      recipesCount: recipesCount,
      purchasesCount: purchasesCount,
      batchesCount: batchesCount,
    );
  }

  /// 4. Verify and prompt user to apply incoming update package (.dpos)
  static Future<void> handleIncomingPackageFile(
    BuildContext context,
    String filePath, {
    String? appliedByUserId,
    VoidCallback? onApplied,
  }) async {
    try {
      final parsedData = await verifyAndParsePackage(filePath);
      if (!context.mounted) return;

      final products = (parsedData['products'] as List? ?? []).length;
      final ingredients = (parsedData['ingredients'] as List? ?? []).length;
      final recipes = (parsedData['recipes'] as List? ?? []).length;
      final purchases = (parsedData['purchases'] as List? ?? []).length;
      final batches = (parsedData['stock_batches'] as List? ?? []).length;
      final createdAt = parsedData['created_at']?.toString() ?? '-';

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.mark_email_read_outlined, color: Color(0xFF128C7E)),
              SizedBox(width: 8),
              Expanded(child: Text('Paket Pembaruan dari Owner', style: TextStyle(fontSize: 16))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Paket pembaruan aman diverifikasi:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Text('• Waktu Dibuat: $createdAt', style: const TextStyle(fontSize: 12)),
              Text('• Menu & Produk: $products item', style: const TextStyle(fontSize: 12)),
              Text('• Bahan Baku & Stok: $ingredients item', style: const TextStyle(fontSize: 12)),
              Text('• Resep Minuman: $recipes resep', style: const TextStyle(fontSize: 12)),
              Text('• Pembelian Bahan: $purchases catatan', style: const TextStyle(fontSize: 12)),
              if (batches > 0) Text('• Batch & Kedaluwarsa: $batches batch', style: const TextStyle(fontSize: 12)),
              const Divider(height: 20),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Data transaksi penjualan, riwayat kasir, dan shift yang ada di HP kasir TETAP AMAN dan TIDAK AKAN terhapus.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF128C7E), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF128C7E),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Terapkan Sekarang'),
            ),
          ],
        ),
      );

      if (confirmed == true && context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );

        final res = await applyPackage(
          data: parsedData,
          appliedByUserId: appliedByUserId ?? 'usr_cashier',
        );

        if (context.mounted) {
          Navigator.of(context).pop(); // dismiss loading indicator
          onApplied?.call();

          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Pembaruan Berhasil Diterapkan!'),
              content: Text(
                'Resep, stok, dan menu toko telah diperbarui secara aman:\n\n'
                '• ${res.productsCount} Produk/Menu disinkronkan\n'
                '• ${res.ingredientsCount} Bahan Baku & Stok diperbarui\n'
                '• ${res.recipesCount} Resep racikan diperbarui\n'
                '• ${res.purchasesCount} Riwayat pembelian bahan dicatat\n'
                '• ${res.batchesCount} Batch kedaluwarsa diperbarui',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Selesai'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menerapkan pembaruan: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }
}
