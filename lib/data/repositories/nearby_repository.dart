import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:ikrili/config/api_config.dart';
import 'package:ikrili/domain/entities/nearby_owner.dart';

class NearbyRepository {
  NearbyRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<NearbyOwner>> findOwners({
    required double latitude,
    required double longitude,
    required double radiusKm,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/owners/nearby').replace(
      queryParameters: {
        'latitude': '$latitude',
        'longitude': '$longitude',
        'radius_km': '$radiusKm',
        if (startDate != null) 'start_date': _date(startDate),
        if (endDate != null) 'end_date': _date(endDate),
      },
    );
    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Nearby search failed (${response.statusCode})');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['owners'] as List<dynamic>)
        .map((item) => NearbyOwner.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  String _date(DateTime value) => value.toIso8601String().substring(0, 10);
}

