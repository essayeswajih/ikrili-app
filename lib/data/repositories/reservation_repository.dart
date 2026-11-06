import 'package:sqflite/sqflite.dart';

import '../../domain/entities/car.dart';
import '../../domain/entities/reservation.dart';
import '../../domain/entities/user.dart';
import '../datasources/app_database.dart';
import '../models/reservation_model.dart';
import 'car_repository.dart';
import 'notification_repository.dart';
import 'user_repository.dart';

class ReservationException implements Exception {
  const ReservationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ReservationRepository {
  ReservationRepository._();

  static final ReservationRepository instance = ReservationRepository._();

  Future<Database> get _db async => AppDatabase.instance.database;

  Future<Reservation> createReservation({
    required Car car,
    required User renter,
    required DateTime startDate,
    required DateTime endDate,
    required String pickupTime,
  }) async {
    final cleanStart = _dateOnly(startDate);
    final cleanEnd = _dateOnly(endDate);
    if (cleanEnd.isBefore(cleanStart)) {
      throw const ReservationException('End date must be on or after start date.');
    }
    if (renter.isBlocked) {
      throw const ReservationException('Blocked users cannot reserve cars.');
    }
    if (car.ownerId == renter.id) {
      throw const ReservationException('Owners cannot reserve their own cars.');
    }
    if (!car.isAvailable) {
      throw const ReservationException('This car is currently unavailable.');
    }
    if (await hasApprovedOverlap(car.id, startDate, endDate)) {
      throw const ReservationException('Selected dates are already reserved.');
    }

    final now = DateTime.now();
    final totalDays = cleanEnd.difference(cleanStart).inDays + 1;
    final totalCost = totalDays * car.price;
    final reservation = ReservationModel(
      id: 'reservation-${now.microsecondsSinceEpoch}',
      carId: car.id,
      renterId: renter.id,
      ownerId: car.ownerId,
      startDate: cleanStart,
      endDate: cleanEnd,
      pickupTime: pickupTime,
      totalDays: totalDays,
      totalCost: totalCost,
      status: ReservationStatus.pending,
      depositAmount: totalCost * 0.10,
      depositPaid: false,
      createdAt: now,
      updatedAt: now,
      car: car,
      renter: renter,
      owner: car.user,
    );

    final db = await _db;
    await db.insert(AppDatabase.tableReservations, reservation.toRow());
    await NotificationRepository.instance.createNotification(
      userId: car.ownerId,
      title: 'New booking request',
      message:
          '${renter.name} requested ${car.brand} ${car.model} for $totalDays day(s).',
      type: 'reservation_requested',
      reservationId: reservation.id,
    );
    return reservation;
  }

  Future<List<Reservation>> getAllReservations() async {
    await _expireAwaitingPayments();
    final db = await _db;
    final rows = await db.query(
      AppDatabase.tableReservations,
      orderBy: 'created_at DESC',
    );
    return Future.wait(rows.map(_reservationFromRow));
  }

  Future<List<Reservation>> getReservationsByOwner(String ownerId) async {
    await _expireAwaitingPayments();
    final db = await _db;
    final rows = await db.query(
      AppDatabase.tableReservations,
      where: 'owner_id = ?',
      whereArgs: [ownerId],
      orderBy: 'created_at DESC',
    );
    return Future.wait(rows.map(_reservationFromRow));
  }

  Future<List<Reservation>> getReservationsByRenter(String renterId) async {
    await _expireAwaitingPayments();
    final db = await _db;
    final rows = await db.query(
      AppDatabase.tableReservations,
      where: 'renter_id = ?',
      whereArgs: [renterId],
      orderBy: 'created_at DESC',
    );
    return Future.wait(rows.map(_reservationFromRow));
  }

  Future<List<Reservation>> getReservationsByCar(String carId) async {
    await _expireAwaitingPayments();
    final db = await _db;
    final rows = await db.query(
      AppDatabase.tableReservations,
      where: 'car_id = ?',
      whereArgs: [carId],
      orderBy: 'created_at DESC',
    );
    return Future.wait(rows.map(_reservationFromRow));
  }

  Future<void> approveReservation(String reservationId) async {
    final reservation = await _getReservationById(reservationId);
    if (reservation == null || !reservation.isPending) return;
    if (await hasApprovedOverlap(
      reservation.carId,
      reservation.startDate,
      reservation.endDate,
      excludingReservationId: reservation.id,
    )) {
      throw const ReservationException('Selected dates are already reserved.');
    }
    await _setStatus(reservation, ReservationStatus.awaitingPayment);
    await NotificationRepository.instance.createNotification(
      userId: reservation.renterId,
      title: 'Booking approved',
      message:
          'Your request was approved. Pay ${reservation.depositAmount.toStringAsFixed(0)} DT to reserve the car.',
      type: 'reservation_approved_payment_due',
      reservationId: reservation.id,
    );
  }

  Future<void> rejectReservation(String reservationId) async {
    final reservation = await _getReservationById(reservationId);
    if (reservation == null || !reservation.isPending) return;
    await _setStatus(reservation, ReservationStatus.rejected);
    await NotificationRepository.instance.createNotification(
      userId: reservation.renterId,
      title: 'Booking rejected',
      message: 'Your booking request was rejected by the owner.',
      type: 'reservation_rejected',
      reservationId: reservation.id,
    );
  }

  Future<void> startReservation(String reservationId) async {
    final reservation = await _getReservationById(reservationId);
    if (reservation == null || !reservation.isApproved) return;
    await _setStatus(reservation, ReservationStatus.active);
    await NotificationRepository.instance.createNotification(
      userId: reservation.renterId,
      title: 'Rental started',
      message: 'Your rental is now active.',
      type: 'reservation_started',
      reservationId: reservation.id,
    );
  }

  Future<void> completeReservation(String reservationId) async {
    final reservation = await _getReservationById(reservationId);
    if (reservation == null || !reservation.isActive) return;
    await _setStatus(reservation, ReservationStatus.completed);
    await CarRepository.instance.removeReservedDates(
      reservation.carId,
      _createDaysRange(reservation.startDate, reservation.endDate),
    );
    await NotificationRepository.instance.createNotification(
      userId: reservation.renterId,
      title: 'Rental completed',
      message: 'Your rental has been completed.',
      type: 'reservation_completed',
      reservationId: reservation.id,
    );
  }

  Future<void> expireReservation(String reservationId) async {
    final reservation = await _getReservationById(reservationId);
    if (reservation == null || !reservation.isAwaitingPayment) return;
    await _setStatus(reservation, ReservationStatus.expired);
    await NotificationRepository.instance.createNotification(
      userId: reservation.renterId,
      title: 'Payment window expired',
      message: 'The deposit payment window for your reservation expired.',
      type: 'reservation_expired',
      reservationId: reservation.id,
    );
  }

  Future<void> payDeposit(String reservationId) async {
    final reservation = await _getReservationById(reservationId);
    if (reservation == null || !reservation.isAwaitingPayment) return;
    if (await hasApprovedOverlap(
      reservation.carId,
      reservation.startDate,
      reservation.endDate,
      excludingReservationId: reservation.id,
    )) {
      throw const ReservationException('Selected dates are already reserved.');
    }

    final now = DateTime.now();
    final db = await _db;
    await db.update(
      AppDatabase.tableReservations,
      {
        'status': ReservationStatus.approved,
        'deposit_paid': 1,
        'deposit_paid_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [reservation.id],
    );
    await CarRepository.instance.reserveDates(
      reservation.carId,
      _createDaysRange(reservation.startDate, reservation.endDate),
    );
    await NotificationRepository.instance.createNotification(
      userId: reservation.ownerId,
      title: 'Deposit paid',
      message: 'The renter paid the 10% deposit. The booking is confirmed.',
      type: 'deposit_paid_owner',
      reservationId: reservation.id,
    );
    await NotificationRepository.instance.createNotification(
      userId: reservation.renterId,
      title: 'Reservation confirmed',
      message: 'Your 10% deposit was paid and your car is reserved.',
      type: 'deposit_paid_renter',
      reservationId: reservation.id,
    );
  }

  Future<void> cancelReservation(String reservationId) async {
    final reservation = await _getReservationById(reservationId);
    if (reservation == null ||
        reservation.status == ReservationStatus.cancelled ||
        reservation.status == ReservationStatus.rejected) {
      return;
    }
    await _setStatus(reservation, ReservationStatus.cancelled);
    if (reservation.status == ReservationStatus.approved) {
      await CarRepository.instance.removeReservedDates(
        reservation.carId,
        _createDaysRange(reservation.startDate, reservation.endDate),
      );
    }
    await NotificationRepository.instance.createNotification(
      userId: reservation.ownerId,
      title: 'Reservation cancelled',
      message: 'A reservation for your car was cancelled.',
      type: 'reservation_cancelled_owner',
      reservationId: reservation.id,
    );
    await NotificationRepository.instance.createNotification(
      userId: reservation.renterId,
      title: 'Reservation cancelled',
      message: 'Your reservation was cancelled.',
      type: 'reservation_cancelled_renter',
      reservationId: reservation.id,
    );
  }

  Future<bool> hasApprovedOverlap(
    String carId,
    DateTime startDate,
    DateTime endDate, {
    String? excludingReservationId,
  }) async {
    final db = await _db;
    final rows = await db.query(
      AppDatabase.tableReservations,
      where: excludingReservationId == null
          ? 'car_id = ? AND status = ?'
          : 'car_id = ? AND status = ? AND id != ?',
      whereArgs: excludingReservationId == null
          ? [carId, ReservationStatus.approved]
          : [carId, ReservationStatus.approved, excludingReservationId],
    );
    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);
    for (final row in rows) {
      final reservation = ReservationModel.fromRow(row);
      if (!end.isBefore(reservation.startDate) &&
          !start.isAfter(reservation.endDate)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _setStatus(Reservation reservation, String status) async {
    final db = await _db;
    await db.update(
      AppDatabase.tableReservations,
      {'status': status, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [reservation.id],
    );
  }

  Future<void> _expireAwaitingPayments() async {
    final cutoff = DateTime.now()
        .subtract(const Duration(hours: 24))
        .toIso8601String();
    final db = await _db;
    final rows = await db.query(
      AppDatabase.tableReservations,
      columns: ['id'],
      where: 'status = ? AND created_at < ?',
      whereArgs: [ReservationStatus.awaitingPayment, cutoff],
    );
    for (final row in rows) {
      await expireReservation(row['id'] as String);
    }
  }

  Future<Reservation?> _getReservationById(String id) async {
    final db = await _db;
    final rows = await db.query(
      AppDatabase.tableReservations,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _reservationFromRow(rows.first);
  }

  Future<Reservation> _reservationFromRow(Map<String, dynamic> row) async {
    final car = await CarRepository.instance.getCarById(
      row['car_id'] as String,
    );
    final renter = await UserRepository.instance.getUserById(
      row['renter_id'] as String,
    );
    final owner = await UserRepository.instance.getUserById(
      row['owner_id'] as String,
    );
    return ReservationModel.fromRow(
      row,
      car: car,
      renter: renter,
      owner: owner,
    );
  }

  List<DateTime> _createDaysRange(DateTime start, DateTime end) {
    final days = <DateTime>[];
    var current = _dateOnly(start);
    final endDay = _dateOnly(end);
    while (!current.isAfter(endDay)) {
      days.add(current);
      current = current.add(const Duration(days: 1));
    }
    return days;
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
