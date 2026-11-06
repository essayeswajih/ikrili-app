import 'car.dart';
import 'user.dart';

class ReservationStatus {
  const ReservationStatus._();

  static const pending = 'pending';
  static const awaitingPayment = 'awaiting_payment';
  static const approved = 'approved';
  static const rejected = 'rejected';
  static const cancelled = 'cancelled';
  static const completed = 'completed';

  static const all = [
    pending,
    awaitingPayment,
    approved,
    rejected,
    cancelled,
    completed,
  ];
}

class Reservation {
  const Reservation({
    required this.id,
    required this.carId,
    required this.renterId,
    required this.ownerId,
    required this.startDate,
    required this.endDate,
    required this.pickupTime,
    required this.totalDays,
    required this.totalCost,
    required this.status,
    required this.depositAmount,
    required this.depositPaid,
    required this.createdAt,
    required this.updatedAt,
    this.depositPaidAt,
    this.car,
    this.renter,
    this.owner,
  });

  final String id;
  final String carId;
  final String renterId;
  final String ownerId;
  final DateTime startDate;
  final DateTime endDate;
  final String pickupTime;
  final int totalDays;
  final double totalCost;
  final String status;
  final double depositAmount;
  final bool depositPaid;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? depositPaidAt;
  final Car? car;
  final User? renter;
  final User? owner;

  bool get isPending => status == ReservationStatus.pending;
  bool get isAwaitingPayment => status == ReservationStatus.awaitingPayment;
  bool get isApproved => status == ReservationStatus.approved;
  bool get isActive => status == ReservationStatus.active;
  bool get isCompleted => status == ReservationStatus.completed;
  bool get isCancelled => status == ReservationStatus.cancelled;
  bool get isTerminal =>
      status == ReservationStatus.completed ||
      status == ReservationStatus.rejected ||
      status == ReservationStatus.cancelled ||
      status == ReservationStatus.expired;

  Reservation copyWith({
    String? status,
    double? depositAmount,
    bool? depositPaid,
    DateTime? depositPaidAt,
    DateTime? updatedAt,
    Car? car,
    User? renter,
    User? owner,
  }) {
    return Reservation(
      id: id,
      carId: carId,
      renterId: renterId,
      ownerId: ownerId,
      startDate: startDate,
      endDate: endDate,
      pickupTime: pickupTime,
      totalDays: totalDays,
      totalCost: totalCost,
      status: status ?? this.status,
      depositAmount: depositAmount ?? this.depositAmount,
      depositPaid: depositPaid ?? this.depositPaid,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      depositPaidAt: depositPaidAt ?? this.depositPaidAt,
      car: car ?? this.car,
      renter: renter ?? this.renter,
      owner: owner ?? this.owner,
    );
  }
}
