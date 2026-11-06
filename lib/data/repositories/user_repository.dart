import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/entities/car.dart';
import '../../domain/entities/user.dart';
import '../datasources/app_database.dart';

class UserRoles {
  const UserRoles._();

  static const carOwner = 'car_owner';
  static const carRenter = 'car_renter';
  static const admin = 'admin';
  static const all = [carOwner, carRenter, admin];

  static String label(String role) {
    switch (role) {
      case carOwner:
        return 'مالك سيارة';
      case carRenter:
        return 'مستأجر سيارات';
      case admin:
        return 'مشرف';
      default:
        return 'Member';
    }
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// SQLite-backed repository handling users/authentication.
///
/// Replaces the old SharedPreferences-based `LocalAuthService`. The current
/// signed-in session (just the email) is still tracked via SharedPreferences
/// since that's cheap ephemeral state, but all user data lives in SQLite.
class UserRepository {
  UserRepository._();

  static final UserRepository instance = UserRepository._();

  static const _currentEmailKey = 'ikrili_current_email';

  User? _currentUser;
  bool _isReady = false;

  User? get currentUser => _currentUser;

  bool get isSignedIn => _currentUser != null;

  Future<Database> get _db async => AppDatabase.instance.database;

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  /// Loads the persisted session (if any) and seeds demo accounts on first
  /// run. Must be called once before the app starts using this repository.
  Future<void> restoreSession() async {
    if (_isReady) return;

    await _seedDemoAccountsIfNeeded();

    final prefs = await SharedPreferences.getInstance();
    final currentEmail = prefs.getString(_currentEmailKey);
    if (currentEmail != null) {
      final user = await _findUserByEmail(currentEmail);
      if (user != null && !user.isBlocked) {
        _currentUser = user;
      } else {
        await prefs.remove(_currentEmailKey);
      }
    }

    _isReady = true;
  }

  Future<User> login({required String email, required String password}) async {
    await restoreSession();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw const AuthException('Email and password are required.');
    }
    final db = await _db;
    final rows = await db.query(
      AppDatabase.tableUsers,
      where: 'email = ?',
      whereArgs: [normalizedEmail],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const AuthException('Invalid email or password.');
    }

    final row = rows.first;
    if (row['password_hash'] != _hashPassword(password)) {
      throw const AuthException('Invalid email or password.');
    }

    final user = await _userFromRow(row);
    if (user.isBlocked) {
      throw const AuthException('This account is blocked. Contact support.');
    }

    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentEmailKey, normalizedEmail);
    return user;
  }

  Future<User> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String role,
  }) async {
    await restoreSession();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final trimmedName = name.trim();
    final normalizedEmail = email.trim().toLowerCase();
    final trimmedPhone = phone.trim();
    if (trimmedName.length < 2) {
      throw const AuthException('Enter your full name.');
    }
    if (!_isValidEmail(normalizedEmail)) {
      throw const AuthException('Enter a valid email address.');
    }
    if (trimmedPhone.length < 8) {
      throw const AuthException('Enter a valid phone number.');
    }
    if (password.length < 8) {
      throw const AuthException('Password must be at least 8 characters.');
    }
    if (!UserRoles.all.contains(role)) {
      throw const AuthException('Choose a valid account type.');
    }
    final existing = await _findUserByEmail(normalizedEmail);
    if (existing != null) {
      throw const AuthException('An account with this email already exists.');
    }

    final now = DateTime.now();
    final id = 'local-${now.microsecondsSinceEpoch}';
    final user = User(
      id: id,
      name: trimmedName,
      email: normalizedEmail,
      phone: trimmedPhone,
      address: '',
      image: '',
      role: role,
      createdAt: now,
      updatedAt: now,
      rating: role == UserRoles.admin ? 5 : 0,
      location: 'Tunis',
      cars: const [],
      coins: role == UserRoles.carRenter ? 25 : 0,
    );

    final db = await _db;
    await db.insert(AppDatabase.tableUsers, {
      ..._userToRow(user),
      'password_hash': _hashPassword(password),
    });

    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentEmailKey, normalizedEmail);
    return user;
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  void resetForTests() {
    _currentUser = null;
    _isReady = false;
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentEmailKey);
  }

  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    await restoreSession();
    if (newPassword.length < 8) {
      throw const AuthException('Password must be at least 8 characters.');
    }
    final normalizedEmail = email.trim().toLowerCase();
    final user = await _findUserByEmail(normalizedEmail);
    if (user == null) throw const AuthException('Account not found.');
    final db = await _db;
    await db.update(
      AppDatabase.tableUsers,
      {
        'password_hash': _hashPassword(newPassword),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'email = ?',
      whereArgs: [normalizedEmail],
    );
  }

  Future<void> updateUser(User user) async {
    final db = await _db;
    await db.update(
      AppDatabase.tableUsers,
      _userToRow(user),
      where: 'id = ?',
      whereArgs: [user.id],
    );
    if (_currentUser?.id == user.id) {
      _currentUser = user;
    }
  }

  Future<void> deleteUser(String email) async {
    final db = await _db;
    await db.delete(
      AppDatabase.tableUsers,
      where: 'email = ?',
      whereArgs: [email],
    );
    if (_currentUser?.email == email) {
      await logout();
    }
  }

  Future<void> toggleBlocked(String email) async {
    final user = await _findUserByEmail(email);
    if (user == null || user.role == UserRoles.admin) return;
    await updateUser(
      user.copyWith(isBlocked: !user.isBlocked, updatedAt: DateTime.now()),
    );
  }

  Future<void> rateUser(String email, double rating) async {
    final user = await _findUserByEmail(email);
    if (user == null) return;
    await updateUser(
      user.copyWith(
        rating: rating.clamp(0, 5).toDouble(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Returns all users (without their `cars` populated - use CarRepository
  /// to fetch cars per-owner if needed).
  Future<List<User>> getAllUsers() async {
    final db = await _db;
    final rows = await db.query(AppDatabase.tableUsers, orderBy: 'name ASC');
    return Future.wait(rows.map(_userFromRow));
  }

  Future<User?> getUserById(String id) async {
    final db = await _db;
    final rows = await db.query(
      AppDatabase.tableUsers,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _userFromRow(rows.first);
  }

  Future<User?> _findUserByEmail(String email) async {
    final db = await _db;
    final rows = await db.query(
      AppDatabase.tableUsers,
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _userFromRow(rows.first);
  }

  Future<User> _userFromRow(Map<String, dynamic> row) async {
    return User(
      id: row['id'] as String,
      name: row['name'] as String,
      email: row['email'] as String,
      phone: row['phone'] as String,
      address: row['address'] as String? ?? '',
      image: row['image'] as String? ?? '',
      role: row['role'] as String? ?? UserRoles.carOwner,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      rating: (row['rating'] as num?)?.toDouble() ?? 0,
      location: row['location'] as String? ?? 'Tunis',
      cars: const <Car>[],
      coins: (row['coins'] as num?)?.toInt() ?? 0,
      isBlocked: (row['is_blocked'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> _userToRow(User user) => {
    'id': user.id,
    'name': user.name,
    'email': user.email,
    'phone': user.phone,
    'address': user.address,
    'image': user.image,
    'role': user.role,
    'rating': user.rating,
    'location': user.location,
    'coins': user.coins,
    'is_blocked': user.isBlocked ? 1 : 0,
    'created_at': user.createdAt.toIso8601String(),
    'updated_at': user.updatedAt.toIso8601String(),
  };

  Future<void> _seedDemoAccountsIfNeeded() async {
    final db = await _db;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM ${AppDatabase.tableUsers}'),
    );
    if (count != null && count > 0) return;

    final now = DateTime(2025, 1, 1);
    final demoOwner = User(
      id: '1',
      name: 'Demo Renter',
      email: 'owner@ikrili.com',
      phone: '+216 20 000 001',
      address: 'Tunis',
      image: '',
      role: UserRoles.carOwner,
      createdAt: now,
      updatedAt: now,
      rating: 4.8,
      location: 'Tunis',
      cars: const [],
    );
    final demoDriver = User(
      id: 'demo-driver',
      name: 'Demo أجير سيارات',
      email: 'driver@ikrili.com',
      phone: '+216 20 000 002',
      address: 'Sousse',
      image: '',
      role: UserRoles.carRenter,
      createdAt: now,
      updatedAt: now,
      rating: 4.5,
      location: 'Sousse',
      cars: const [],
      coins: 140,
    );
    final demoAdmin = User(
      id: 'demo-admin',
      name: 'Ikrili Admin',
      email: 'admin@ikrili.com',
      phone: '+216 20 000 003',
      address: 'Tunis',
      image: '',
      role: UserRoles.admin,
      createdAt: now,
      updatedAt: now,
      rating: 5,
      location: 'Tunis',
      cars: const [],
    );

    final batch = db.batch();
    batch.insert(AppDatabase.tableUsers, {
      ..._userToRow(demoOwner),
      'password_hash': _hashPassword('demo1234'),
    });
    batch.insert(AppDatabase.tableUsers, {
      ..._userToRow(demoDriver),
      'password_hash': _hashPassword('demo1234'),
    });
    batch.insert(AppDatabase.tableUsers, {
      ..._userToRow(demoAdmin),
      'password_hash': _hashPassword('admin123'),
    });
    // 'demo@ikrili.com' aliases the owner account for the pre-filled login form.
    batch.insert(AppDatabase.tableUsers, {
      ..._userToRow(
        demoOwner.copyWith(id: 'demo-alias', email: 'demo@ikrili.com'),
      ),
      'password_hash': _hashPassword('demo1234'),
    });
    await batch.commit(noResult: true);
  }
}
