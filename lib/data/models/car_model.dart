import 'package:ikrili/data/models/user_model.dart';

import '../../domain/entities/car.dart';
import '../../domain/entities/user.dart';

class CarModel extends Car {
  CarModel({
    required super.id,
    required super.brand,
    required super.model,
    required super.year,
    required super.price,
    required super.currency,
    required super.image,
    required super.color,
    required super.seats,
    required super.gearbox,
    required super.fuel,
    required super.mileage,
    required super.description,
    required super.location,
    required super.isAvailable,
    required super.createdAt,
    required super.updatedAt,
    required super.user,
    required super.ownerId,
    required super.registrationNumber,
    required super.reservedDates,
  });

  factory CarModel.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    final user = userJson is User
        ? userJson
        : UserModel.fromJson(userJson as Map<String, dynamic>);
    final reservedDates = (json['reservedDates'] as List<dynamic>? ?? const [])
        .map((x) => x is DateTime ? x : DateTime.parse(x as String))
        .toList();

    return CarModel(
      id: json['id'] as String,
      brand: json['brand'] as String,
      model: json['model'] as String,
      year: json['year'] as int,
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String,
      image: json['image'] as String,
      color: json['color'] as String,
      seats: json['seats'] as int,
      gearbox: json['gearbox'] as String,
      fuel: json['fuel'] as String,
      mileage: json['mileage'] as int,
      description: json['description'] as String,
      location: json['location'] as String,
      isAvailable: json['isAvailable'] == true || json['isAvailable'] == 1,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      user: user,
      ownerId: json['ownerId'] as String? ?? user.id,
      registrationNumber: json['registrationNumber'] as String,
      reservedDates: reservedDates,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'brand': brand,
    'model': model,
    'year': year,
    'price': price,
    'currency': currency,
    'image': image,
    'color': color,
    'seats': seats,
    'gearbox': gearbox,
    'fuel': fuel,
    'mileage': mileage,
    'description': description,
    'location': location,
    'isAvailable': isAvailable,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'ownerId': ownerId,
    'user': {
      'id': user.id,
      'name': user.name,
      'email': user.email,
      'phone': user.phone,
      'address': user.address,
      'image': user.image,
      'role': user.role,
      'createdAt': user.createdAt.toIso8601String(),
      'updatedAt': user.updatedAt.toIso8601String(),
      'rating': user.rating,
      'location': user.location,
      'cars': const [],
    },
    'registrationNumber': registrationNumber,
    'reservedDates': reservedDates
        .map((date) => date.toIso8601String())
        .toList(),
  };
}
