import 'package:ikrili/domain/entities/user.dart';

class Car {
  final String id;
  final String brand;
  final String model;
  final int year;
  final double price;
  final String currency;
  final String image;
  final String color;
  final int seats;
  final String gearbox;
  final String fuel;
  final int mileage;
  final String description;
  final String location;
  final bool isAvailable;
  final DateTime createdAt;
  final DateTime updatedAt;
  final User user;
  final String ownerId;
  final String registrationNumber;
  final List<DateTime> reservedDates;

  Car({
    required this.id,
    required this.brand,
    required this.model,
    required this.year,
    required this.price,
    required this.currency,
    required this.image,
    required this.color,
    required this.seats,
    required this.gearbox,
    required this.fuel,
    required this.mileage,
    required this.description,
    required this.location,
    required this.isAvailable,
    required this.createdAt,
    required this.updatedAt,
    required this.user,
    required this.ownerId,
    required this.registrationNumber,
    required this.reservedDates,
  });

  Car copyWith({
    String? id,
    String? brand,
    String? model,
    int? year,
    double? price,
    String? currency,
    String? image,
    String? color,
    int? seats,
    String? gearbox,
    String? fuel,
    int? mileage,
    String? description,
    String? location,
    bool? isAvailable,
    DateTime? createdAt,
    DateTime? updatedAt,
    User? user,
    String? ownerId,
    String? registrationNumber,
    List<DateTime>? reservedDates,
  }) {
    return Car(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      image: image ?? this.image,
      color: color ?? this.color,
      seats: seats ?? this.seats,
      gearbox: gearbox ?? this.gearbox,
      fuel: fuel ?? this.fuel,
      mileage: mileage ?? this.mileage,
      description: description ?? this.description,
      location: location ?? this.location,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      user: user ?? this.user,
      ownerId: ownerId ?? this.ownerId,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      reservedDates: reservedDates ?? this.reservedDates,
    );
  }
}
