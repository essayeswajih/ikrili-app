import '../../domain/entities/car.dart';
import '../../domain/entities/reservation.dart';
import '../../domain/entities/user.dart';

class ReservationModel extends Reservation {
  const ReservationModel({
    required super.id,
    required super.carId,
    required super.renterId,
    required super.ownerId,
    required super.startDate,
    required super.endDate,
    required super.pickupTime,
    required super.totalDays,
    required super.totalCost,
    required super.status,
    required super.depositAmount,
    required super.depositPaid,
    required super.createdAt,
    required super.updatedAt,
    super.depositPaidAt,
    super.car,
    super.renter,
    super.owner,
  });

  factory ReservationModel.fromRow(
    Map<String, dynamic> row, {
    Car? car,
    User? renter,
    User? owner,
  }) {
    return ReservationModel(
      id: row['id'] as String,
      carId: row['car_id'] as String,
      renterId: row['renter_id'] as String,
      ownerId: row['owner_id'] as String,
      startDate: DateTime.parse(row['start_date'] as String),
      endDate: DateTime.parse(row['end_date'] as String),
      pickupTime: row['pickup_time'] as String,
      totalDays: (row['total_days'] as num).toInt(),
      totalCost: (row['total_cost'] as num).toDouble(),
      status: row['status'] as String,
      depositAmount:
          (row['deposit_amount'] as num?)?.toDouble() ??
          (row['total_cost'] as num).toDouble() * 0.10,
      depositPaid:
          (row['deposit_paid'] as int? ?? 0) == 1 ||
          row['status'] == ReservationStatus.approved,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      depositPaidAt: row['deposit_paid_at'] == null
          ? null
          : DateTime.parse(row['deposit_paid_at'] as String),
      car: car,
      renter: renter,
      owner: owner,
    );
  }

  Map<String, dynamic> toRow() => {
    'id': id,
    'car_id': carId,
    'renter_id': renterId,
    'owner_id': ownerId,
    'start_date': _dateOnly(startDate).toIso8601String(),
    'end_date': _dateOnly(endDate).toIso8601String(),
    'pickup_time': pickupTime,
    'total_days': totalDays,
    'total_cost': totalCost,
    'status': status,
    'deposit_amount': depositAmount,
    'deposit_paid': depositPaid ? 1 : 0,
    'deposit_paid_at': depositPaidAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
