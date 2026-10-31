import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../constants/app_constants.dart';
import 'database_schema.dart';
import 'seed_data.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();
  AppDatabase._internal();

  Database? _db;

  /// Allow injecting a database (e.g., in-memory sqlite for tests)
  void setDatabaseForTesting(Database db) {
    _db = db;
  }

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<String> getDatabasePath() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return p.join(dbFolder.path, AppConstants.dbName);
  }

  Future<Database> _initDatabase() async {
    final path = await getDatabasePath();
    final dbDir = Directory(p.dirname(path));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }

    return await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onOpen: (db) async {
        try {
          await db.execute('ALTER TABLE stores ADD COLUMN logo_path TEXT;');
        } catch (_) {}
        try {
          await db.execute("ALTER TABLE users ADD COLUMN shift_start_time TEXT DEFAULT '08:00';");
        } catch (_) {}
        try {
          await db.execute("ALTER TABLE users ADD COLUMN shift_end_time TEXT DEFAULT '16:00';");
        } catch (_) {}
        try {
          await db.execute("ALTER TABLE users ADD COLUMN shift_name TEXT DEFAULT 'Shift Pagi';");
        } catch (_) {}
        try {
          await db.execute("ALTER TABLE users ADD COLUMN permissions TEXT DEFAULT '';");
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE attendance ADD COLUMN photo_path TEXT;');
        } catch (_) {}
      },
      onCreate: (db, version) async {
        final batch = db.batch();
        for (final query in DatabaseSchema.createTablesQueries) {
          batch.execute(query);
        }
        for (final query in DatabaseSchema.createIndicesQueries) {
          batch.execute(query);
        }
        await batch.commit(noResult: true);

        // Seed default initial data
        await SeedData.populateInitialData(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Safe migrations - preserve user data
        if (oldVersion < 2) {
          // Future migration handlers
        }
      },
    );
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
