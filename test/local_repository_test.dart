import 'package:flutter_test/flutter_test.dart';
import 'package:ikrili/data/datasources/app_database.dart';
import 'package:ikrili/data/repositories/car_repository.dart';
import 'package:ikrili/data/repositories/notification_repository.dart';
import 'package:ikrili/data/repositories/reservation_repository.dart';
import 'package:ikrili/data/services/local_auth_service.dart';
import 'package:ikrili/domain/entities/reservation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> _resetLocalRepositories() async {
  SharedPreferences.setMockInitialValues({});
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;
  await AppDatabase.instance.configureForTests(inMemoryDatabasePath);
  LocalAuthService.instance.resetForTests();
  CarRepository.instance.resetForTests();
  await LocalAuthService.instance.restoreSession();
  await LocalAuthService.instance.logout();
  await CarRepository.instance.initialize();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('approval waits for deposit before blocking calendar dates', () async {
    await _resetLocalRepositories();
    final car = (await CarRepository.instance.getAllCars()).first;
    final initialReservedCount = car.reservedDates.length;
    final renter = await LocalAuthService.instance.register(
      name: 'Payment Tester',
      email: 'payment@ikrili.local',
      phone: '+21620000097',
      password: 'payment123',
      role: UserRoles.carRenter,
    );

    final reservation = await ReservationRepository.instance.createReservation(
      car: car,
      renter: renter,
      startDate: DateTime(2026, 11, 10),
      endDate: DateTime(2026, 11, 12),
      pickupTime: '9:00 AM',
    );
    await ReservationRepository.instance.approveReservation(reservation.id);

    final awaiting =
        (await ReservationRepository.instance.getReservationsByRenter(
          renter.id,
        )).single;
    expect(awaiting.status, ReservationStatus.awaitingPayment);
    expect(awaiting.depositPaid, isFalse);
    expect(awaiting.depositAmount, awaiting.totalCost * 0.10);
    expect(
      (await CarRepository.instance.getCarById(car.id))!.reservedDates.length,
      initialReservedCount,
    );
  });

  test(
    'paying deposit approves reservation and cancellation frees dates',
    () async {
      await _resetLocalRepositories();
      final car = (await CarRepository.instance.getAllCars()).first;
      final initialReservedCount = car.reservedDates.length;
      final renter = await LocalAuthService.instance.register(
        name: 'Deposit Tester',
        email: 'deposit@ikrili.local',
        phone: '+21620000096',
        password: 'deposit123',
        role: UserRoles.carRenter,
      );

      final reservation = await ReservationRepository.instance
          .createReservation(
            car: car,
            renter: renter,
            startDate: DateTime(2026, 12, 1),
            endDate: DateTime(2026, 12, 1),
            pickupTime: '11:00 AM',
          );
      await ReservationRepository.instance.approveReservation(reservation.id);
      await ReservationRepository.instance.payDeposit(reservation.id);

      var paid = (await ReservationRepository.instance.getReservationsByRenter(
        renter.id,
      )).single;
      expect(paid.status, ReservationStatus.approved);
      expect(paid.depositPaid, isTrue);
      expect(
        (await CarRepository.instance.getCarById(car.id))!.reservedDates.length,
        initialReservedCount + 1,
      );

      await ReservationRepository.instance.cancelReservation(reservation.id);
      paid = (await ReservationRepository.instance.getReservationsByRenter(
        renter.id,
      )).single;
      expect(paid.status, ReservationStatus.cancelled);
      expect(
        (await CarRepository.instance.getCarById(car.id))!.reservedDates.length,
        initialReservedCount,
      );
    },
  );

  test('reservation events create readable local notifications', () async {
    await _resetLocalRepositories();
    final car = (await CarRepository.instance.getAllCars()).first;
    final renter = await LocalAuthService.instance.register(
      name: 'Notification Tester',
      email: 'notify@ikrili.local',
      phone: '+21620000095',
      password: 'notify123',
      role: UserRoles.carRenter,
    );

    final reservation = await ReservationRepository.instance.createReservation(
      car: car,
      renter: renter,
      startDate: DateTime(2027, 1, 3),
      endDate: DateTime(2027, 1, 4),
      pickupTime: '2:00 PM',
    );
    expect(
      await NotificationRepository.instance.getUnreadCount(car.ownerId),
      1,
    );

    await ReservationRepository.instance.approveReservation(reservation.id);
    expect(await NotificationRepository.instance.getUnreadCount(renter.id), 1);

    final notifications = await NotificationRepository.instance
        .getNotificationsForUser(renter.id);
    await NotificationRepository.instance.markRead(notifications.first.id);
    expect(await NotificationRepository.instance.getUnreadCount(renter.id), 0);
  });
}
