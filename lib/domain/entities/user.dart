import 'car.dart';

class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String image;
  final String role;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double rating;
  final String location;
  final List<Car> cars;
  final int coins;
  final bool isBlocked;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.image,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    required this.rating,
    required this.location,
    required this.cars,
    this.coins = 0,
    this.isBlocked = false,
  });

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? image,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? rating,
    String? location,
    List<Car>? cars,
    int? coins,
    bool? isBlocked,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      image: image ?? this.image,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rating: rating ?? this.rating,
      location: location ?? this.location,
      cars: cars ?? this.cars,
      coins: coins ?? this.coins,
      isBlocked: isBlocked ?? this.isBlocked,
    );
  }
}
