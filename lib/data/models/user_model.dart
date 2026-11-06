import '../../domain/entities/user.dart';

class UserModel extends User {
  UserModel({
    required super.id,
    required super.name,
    required super.email,
    required super.phone,
    required super.address,
    required super.image,
    required super.role,
    required super.createdAt,
    required super.updatedAt,
    required super.rating,
    required super.location,
    required super.cars,
    super.coins,
    super.isBlocked,
  });
  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'],
    name: json['name'],
    email: json['email'],
    phone: json['phone'],
    address: json['address'],
    image: json['image'],
    role: json['role'],
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
    rating: json['rating'],
    location: json['location'],
    cars: json['cars'],
  );
}
