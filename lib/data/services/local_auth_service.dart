import 'dart:ui' show Locale;

import '../../domain/entities/user.dart';
import '../repositories/car_repository.dart';
import '../repositories/user_repository.dart' as sqlite_auth;

export '../repositories/user_repository.dart' show AuthException;

class UserRoles {
  const UserRoles._();

  static const carOwner = sqlite_auth.UserRoles.carOwner;
  static const carRenter = sqlite_auth.UserRoles.carRenter;
  static const admin = sqlite_auth.UserRoles.admin;

  static String label(String role, [Locale locale = const Locale('en')]) {
    switch (locale.languageCode) {
      case 'ar':
        switch (role) {
          case carOwner:
            return 'مالك سيارة';
          case carRenter:
            return 'مستأجر سيارات';
          case admin:
            return 'مشرف';
          default:
            return 'عضو';
        }
      case 'fr':
        switch (role) {
          case carOwner:
            return 'Propriétaire de voiture';
          case carRenter:
            return 'Locataire de voiture';
          case admin:
            return 'Administrateur';
          default:
            return 'Membre';
        }
      default:
        switch (role) {
          case carOwner:
            return 'Car owner';
          case carRenter:
            return 'Car renter';
          case admin:
            return 'Admin';
          default:
            return 'Member';
        }
    }
  }
}

class LocalAuthService {
  LocalAuthService._();

  static final LocalAuthService instance = LocalAuthService._();

  final _repository = sqlite_auth.UserRepository.instance;
  List<User> _users = const [];

  User? get currentUser => _repository.currentUser;
  bool get isSignedIn => _repository.isSignedIn;
  List<User> get users => List.unmodifiable(_users);

  Future<void> restoreSession() async {
    await _repository.restoreSession();
    await _refreshUsers();
  }

  Future<User> login({required String email, required String password}) async {
    final user = await _repository.login(email: email, password: password);
    await _refreshUsers();
    return user;
  }

  Future<User> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String role,
  }) async {
    final user = await _repository.register(
      name: name,
      email: email,
      phone: phone,
      password: password,
      role: role,
    );
    await _refreshUsers();
    await CarRepository.instance.refreshCache();
    return user;
  }

  Future<void> logout() async {
    await _repository.logout();
    await _refreshUsers();
  }

  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) {
    return _repository.resetPassword(email: email, newPassword: newPassword);
  }

  Future<void> updateUser(User user) async {
    await _repository.updateUser(user);
    await _refreshUsers();
    await CarRepository.instance.refreshCache();
  }

  Future<void> deleteUser(String email) async {
    await _repository.deleteUser(email);
    await _refreshUsers();
    await CarRepository.instance.refreshCache();
  }

  Future<void> toggleBlocked(String email) async {
    await _repository.toggleBlocked(email);
    await _refreshUsers();
  }

  Future<void> rateUser(String email, double rating) async {
    await _repository.rateUser(email, rating);
    await _refreshUsers();
  }

  Future<void> _refreshUsers() async {
    _users = await _repository.getAllUsers();
  }

  void resetForTests() {
    _users = const [];
    _repository.resetForTests();
  }
}
