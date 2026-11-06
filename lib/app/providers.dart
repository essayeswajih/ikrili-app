import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_preferences.dart';
import '../data/repositories/car_repository.dart';
import '../data/repositories/notification_repository.dart';
import '../data/repositories/reservation_repository.dart';
import '../data/repositories/user_repository.dart';
import '../data/services/local_auth_service.dart';
import '../domain/entities/car.dart';
import '../domain/entities/reservation.dart';
import '../domain/entities/user.dart';

/// Application-wide dependencies. Repositories remain replaceable in tests and
/// can later be switched from local cache implementations to API-backed ones.
final preferencesProvider = ChangeNotifierProvider<AppPreferencesController>(
  (ref) => AppPreferencesController.instance,
);

final currentUserProvider = Provider<User?>((ref) {
  ref.watch(preferencesProvider);
  return LocalAuthService.instance.currentUser;
});

final carRepositoryProvider = Provider<CarRepository>((ref) => CarRepository.instance);
final reservationRepositoryProvider = Provider<ReservationRepository>((ref) => ReservationRepository.instance);
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) => NotificationRepository.instance);
final userRepositoryProvider = Provider<UserRepository>((ref) => UserRepository.instance);

final availableCarsProvider = FutureProvider<List<Car>>((ref) {
  return ref.watch(carRepositoryProvider).getAllCars(availableOnly: true);
});

final currentUserReservationsProvider = FutureProvider<List<Reservation>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const <Reservation>[];
  return user.role == 'car_owner'
      ? ref.watch(reservationRepositoryProvider).getReservationsByOwner(user.id)
      : ref.watch(reservationRepositoryProvider).getReservationsByRenter(user.id);
});
