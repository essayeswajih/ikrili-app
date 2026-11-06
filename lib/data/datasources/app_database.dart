import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Singleton wrapper around the local SQLite database used across the app.
///
/// Schema:
/// - users(id, name, email, phone, address, image, role, password_hash,
///         rating, location, coins, is_blocked, created_at, updated_at)
/// - cars(id, owner_id, brand, model, year, price, currency, image, color,
///        seats, gearbox, fuel, mileage, description, location,
///        is_available, registration_number, created_at, updated_at)
/// - reserved_dates(id, car_id, date)
/// - reservations(id, car_id, renter_id, owner_id, start_date, end_date,
///                pickup_time, total_days, total_cost, status,
///                deposit_amount, deposit_paid, deposit_paid_at,
///                created_at, updated_at)
/// - notifications(id, user_id, title, message, type, is_read, created_at,
///                 reservation_id)
class AppDatabase {
  AppDatabase._internal();

  static final AppDatabase instance = AppDatabase._internal();

  static const _dbName = 'ikrili.db';
  static const _dbVersion = 3;

  static const tableUsers = 'users';
  static const tableCars = 'cars';
  static const tableReservedDates = 'reserved_dates';
  static const tableReservations = 'reservations';
  static const tableNotifications = 'notifications';

  Database? _database;
  bool _ffiInitialized = false;
  String? _databasePathOverride;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _open();
    return _database!;
  }

  void _ensureFfiInitialized() {
    if (_ffiInitialized) return;
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfiNoIsolate;
    }
    _ffiInitialized = true;
  }

  Future<Database> _open() async {
    _ensureFfiInitialized();
    final path =
        _databasePathOverride ?? join(await getDatabasesPath(), _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableUsers (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT NOT NULL UNIQUE,
            phone TEXT NOT NULL,
            address TEXT NOT NULL DEFAULT '',
            image TEXT NOT NULL DEFAULT '',
            role TEXT NOT NULL,
            password_hash TEXT NOT NULL,
            rating REAL NOT NULL DEFAULT 0,
            location TEXT NOT NULL DEFAULT '',
            coins INTEGER NOT NULL DEFAULT 0,
            is_blocked INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE $tableCars (
            id TEXT PRIMARY KEY,
            owner_id TEXT NOT NULL,
            brand TEXT NOT NULL,
            model TEXT NOT NULL,
            year INTEGER NOT NULL,
            price REAL NOT NULL,
            currency TEXT NOT NULL DEFAULT 'DT',
            image TEXT NOT NULL DEFAULT '',
            color TEXT NOT NULL DEFAULT '',
            seats INTEGER NOT NULL DEFAULT 5,
            gearbox TEXT NOT NULL DEFAULT 'Automatic',
            fuel TEXT NOT NULL DEFAULT 'Petrol',
            mileage INTEGER NOT NULL DEFAULT 0,
            description TEXT NOT NULL DEFAULT '',
            location TEXT NOT NULL DEFAULT '',
            is_available INTEGER NOT NULL DEFAULT 1,
            registration_number TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (owner_id) REFERENCES $tableUsers (id)
              ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE $tableReservedDates (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            car_id TEXT NOT NULL,
            date TEXT NOT NULL,
            FOREIGN KEY (car_id) REFERENCES $tableCars (id)
              ON DELETE CASCADE
          )
        ''');

        await _createReservationsTable(db);
        await _createNotificationsTable(db);

        await db.execute(
          'CREATE INDEX idx_cars_owner_id ON $tableCars (owner_id)',
        );
        await db.execute(
          'CREATE INDEX idx_reserved_dates_car_id ON $tableReservedDates (car_id)',
        );
        await _createReservationIndexes(db);
        await _createNotificationIndexes(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createReservationsTable(db);
          await _createReservationIndexes(db);
        }
        if (oldVersion < 3) {
          await _upgradeReservationsForDeposits(db);
          await _createNotificationsTable(db);
          await _createNotificationIndexes(db);
        }
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createReservationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableReservations (
        id TEXT PRIMARY KEY,
        car_id TEXT NOT NULL,
        renter_id TEXT NOT NULL,
        owner_id TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        pickup_time TEXT NOT NULL,
        total_days INTEGER NOT NULL,
        total_cost REAL NOT NULL,
        status TEXT NOT NULL,
        deposit_amount REAL NOT NULL DEFAULT 0,
        deposit_paid INTEGER NOT NULL DEFAULT 0,
        deposit_paid_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (car_id) REFERENCES $tableCars (id) ON DELETE CASCADE,
        FOREIGN KEY (renter_id) REFERENCES $tableUsers (id) ON DELETE CASCADE,
        FOREIGN KEY (owner_id) REFERENCES $tableUsers (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _upgradeReservationsForDeposits(Database db) async {
    await _addColumnIfMissing(
      db,
      tableReservations,
      'deposit_amount',
      'REAL NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      tableReservations,
      'deposit_paid',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(db, tableReservations, 'deposit_paid_at', 'TEXT');
    await db.execute('''
      UPDATE $tableReservations
      SET deposit_amount = total_cost * 0.10,
          deposit_paid = CASE WHEN status = 'approved' THEN 1 ELSE deposit_paid END,
          deposit_paid_at = CASE
            WHEN status = 'approved' AND deposit_paid_at IS NULL THEN updated_at
            ELSE deposit_paid_at
          END
    ''');
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<void> _createReservationIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reservations_car_id ON $tableReservations (car_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reservations_renter_id ON $tableReservations (renter_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reservations_owner_id ON $tableReservations (owner_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reservations_status ON $tableReservations (status)',
    );
  }

  Future<void> _createNotificationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableNotifications (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        type TEXT NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        reservation_id TEXT,
        FOREIGN KEY (user_id) REFERENCES $tableUsers (id) ON DELETE CASCADE,
        FOREIGN KEY (reservation_id) REFERENCES $tableReservations (id)
          ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createNotificationIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON $tableNotifications (user_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON $tableNotifications (is_read)',
    );
  }

  /// Wipes and closes the database. Useful for tests/debugging only.
  Future<void> resetForTests() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  Future<void> configureForTests(String databasePath) async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    _databasePathOverride = databasePath;
  }
}
