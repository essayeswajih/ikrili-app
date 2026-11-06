class NearbyOwner {
  const NearbyOwner({
    required this.ownerId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.lowestPricePerDay,
    required this.currency,
    required this.availableCarsCount,
    required this.rating,
    this.profileImage,
  });

  final String ownerId;
  final String name;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final double lowestPricePerDay;
  final String currency;
  final int availableCarsCount;
  final double rating;
  final String? profileImage;

  factory NearbyOwner.fromJson(Map<String, dynamic> json) => NearbyOwner(
        ownerId: json['owner_id'] as String,
        name: json['name'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        distanceKm: (json['distance_km'] as num).toDouble(),
        lowestPricePerDay: (json['lowest_price_per_day'] as num).toDouble(),
        currency: json['currency'] as String,
        availableCarsCount: (json['available_cars_count'] as num).toInt(),
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        profileImage: json['profile_image'] as String?,
      );
}

