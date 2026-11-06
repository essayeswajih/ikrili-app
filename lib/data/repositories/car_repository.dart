import 'package:sqflite/sqflite.dart';

import '../../domain/entities/car.dart';
import '../../domain/entities/user.dart';
import '../datasources/app_database.dart';
import '../models/car_model.dart';
import 'mock_car_repository.dart';

class CarRepository {
  CarRepository._();

  static final CarRepository instance = CarRepository._();

  final List<Car> _cache = [];
  bool _isReady = false;

  List<Car> get cachedCars => List.unmodifiable(_cache);

  Future<Database> get _db async => AppDatabase.instance.database;

  Future<void> initialize() async {
    if (_isReady) return;
    await seedDemoCarsIfNeeded();
    await refreshCache();
    _isReady = true;
  }

  Future<void> seedDemoCarsIfNeeded() async {
    final db = await _db;
    await _ensureDemoOwnerExists();
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM ${AppDatabase.tableCars}'),
    );
    if (count != null && count > 0) return;

    for (final car in availableCars) {
      await insertCar(car);
    }
  }

  Future<void> refreshCache() async {
    final db = await _db;
    final rows = await db.query(
      AppDatabase.tableCars,
      orderBy: 'created_at DESC',
    );
    _cache
      ..clear()
      ..addAll(await Future.wait(rows.map(_carFromRow)));
  }

  Future<List<Car>> getAllCars({bool availableOnly = false}) async {
    await initialize();
    if (!availableOnly) return cachedCars;
    return cachedCars.where((car) => car.isAvailable).toList(growable: false);
  }

  Future<List<Car>> getCarsByOwner(String ownerId) async {
    await initialize();
    final db = await _db;
    final rows = await db.query(
      AppDatabase.tableCars,
      where: 'owner_id = ?',
      whereArgs: [ownerId],
      orderBy: 'created_at DESC',
    );
    return Future.wait(rows.map(_carFromRow));
  }

  Future<Car?> getCarById(String id) async {
    await initialize();
    for (final car in _cache) {
      if (car.id == id) return car;
    }
    return null;
  }

  Future<void> insertCar(Car car) async {
    final db = await _db;
    await db.insert(
      AppDatabase.tableCars,
      _carToRow(car),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _replaceReservedDates(car.id, car.reservedDates);
    await refreshCache();
  }

  Future<void> updateCar(Car car) async {
    final db = await _db;
    await db.update(
      AppDatabase.tableCars,
      _carToRow(car),
      where: 'id = ?',
      whereArgs: [car.id],
    );
    await _replaceReservedDates(car.id, car.reservedDates);
    await refreshCache();
  }

  Future<void> deleteCar(String carId) async {
    final db = await _db;
    await db.delete(AppDatabase.tableCars, where: 'id = ?', whereArgs: [carId]);
    await refreshCache();
  }

  Future<void> reserveDates(String carId, List<DateTime> dates) async {
    final car = await getCarById(carId);
    if (car == null) return;
    final mergedDates = {
      ...car.reservedDates.map(_dateOnly),
      ...dates.map(_dateOnly),
    }.toList()..sort((a, b) => a.compareTo(b));
    await updateCar(car.copyWith(reservedDates: mergedDates));
  }

  Future<void> removeReservedDates(String carId, List<DateTime> dates) async {
    final car = await getCarById(carId);
    if (car == null) return;
    final datesToRemove = dates.map(_dateOnly).toSet();
    final remainingDates =
        car.reservedDates
            .map(_dateOnly)
            .where((date) => !datesToRemove.contains(date))
            .toList()
          ..sort((a, b) => a.compareTo(b));
    await updateCar(car.copyWith(reservedDates: remainingDates));
  }

  Future<void> _ensureDemoOwnerExists() async {
    final db = await _db;
    final rows = await db.query(
      AppDatabase.tableUsers,
      where: 'id = ?',
      whereArgs: ['1'],
      limit: 1,
    );
    if (rows.isNotEmpty) return;

    final now = DateTime(2025, 1, 1);
    await db.insert(AppDatabase.tableUsers, {
      'id': '1',
      'name': 'Demo Renter',
      'email': 'owner@ikrili.com',
      'phone': '+216 20 000 001',
      'address': 'Tunis',
      'image': '',
      'role': 'car_owner',
      'password_hash': '',
      'rating': 4.8,
      'location': 'Tunis',
      'coins': 0,
      'is_blocked': 0,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _replaceReservedDates(
    String carId,
    List<DateTime> reservedDates,
  ) async {
    final db = await _db;
    final batch = db.batch();
    batch.delete(
      AppDatabase.tableReservedDates,
      where: 'car_id = ?',
      whereArgs: [carId],
    );
    for (final date in reservedDates) {
      batch.insert(AppDatabase.tableReservedDates, {
        'car_id': carId,
        'date': _dateOnly(date).toIso8601String(),
      });
    }
    await batch.commit(noResult: true);
  }

  Future<Car> _carFromRow(Map<String, dynamic> row) async {
    final db = await _db;
    final userRows = await db.query(
      AppDatabase.tableUsers,
      where: 'id = ?',
      whereArgs: [row['owner_id']],
      limit: 1,
    );
    final reservedRows = await db.query(
      AppDatabase.tableReservedDates,
      where: 'car_id = ?',
      whereArgs: [row['id']],
      orderBy: 'date ASC',
    );

    final user = userRows.isEmpty
        ? User(
            id: row['owner_id'] as String,
            name: 'Unknown',
            email: '',
            phone: '',
            address: '',
            image: '',
            role: 'car_owner',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            rating: 0,
            location: '',
            cars: const [],
          )
        : User(
            id: userRows.first['id'] as String,
            name: userRows.first['name'] as String,
            email: userRows.first['email'] as String,
            phone: userRows.first['phone'] as String,
            address: userRows.first['address'] as String? ?? '',
            image: userRows.first['image'] as String? ?? '',
            role: userRows.first['role'] as String? ?? 'car_owner',
            createdAt: DateTime.parse(userRows.first['created_at'] as String),
            updatedAt: DateTime.parse(userRows.first['updated_at'] as String),
            rating: (userRows.first['rating'] as num?)?.toDouble() ?? 0,
            location: userRows.first['location'] as String? ?? '',
            cars: const [],
          );

    return CarModel.fromJson({
      'id': row['id'],
      'brand': row['brand'],
      'model': row['model'],
      'year': row['year'],
      'price': row['price'],
      'currency': row['currency'],
      'image': row['image'],
      'color': row['color'],
      'seats': row['seats'],
      'gearbox': row['gearbox'],
      'fuel': row['fuel'],
      'mileage': row['mileage'],
      'description': row['description'],
      'location': row['location'],
      'isAvailable': row['is_available'],
      'createdAt': row['created_at'],
      'updatedAt': row['updated_at'],
      'ownerId': row['owner_id'],
      'user': user,
      'registrationNumber': row['registration_number'],
      'reservedDates': reservedRows.map((r) => r['date'] as String).toList(),
    });
  }

  Map<String, dynamic> _carToRow(Car car) => {
    'id': car.id,
    'owner_id': car.ownerId,
    'brand': car.brand,
    'model': car.model,
    'year': car.year,
    'price': car.price,
    'currency': car.currency,
    'image': car.image,
    'color': car.color,
    'seats': car.seats,
    'gearbox': car.gearbox,
    'fuel': car.fuel,
    'mileage': car.mileage,
    'description': car.description,
    'location': car.location,
    'is_available': car.isAvailable ? 1 : 0,
    'registration_number': car.registrationNumber,
    'created_at': car.createdAt.toIso8601String(),
    'updated_at': car.updatedAt.toIso8601String(),
  };

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  void resetForTests() {
    _cache.clear();
    _isReady = false;
  }
}
