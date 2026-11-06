import '../../domain/entities/car.dart';
import '../../domain/entities/user.dart';
import 'api_client.dart';

class RemoteUserRepository {
  RemoteUserRepository(this.api);
  final ApiClient api;

  Future<User> me() async {
    final row = await api.getJson('/auth/me');
    final now = DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now();
    return User(id: row['id'], name: row['name'], email: row['email'], phone: '', address: '',
      image: row['image'] ?? '', role: row['role'], createdAt: now, updatedAt: now,
      rating: (row['rating'] as num?)?.toDouble() ?? 0, location: '', cars: const []);
  }
}

class RemoteCarRepository {
  RemoteCarRepository(this.api);
  final ApiClient api;

  Future<List<Car>> list({bool availableOnly = true}) async {
    final rows = await api.getList('/cars', query: {'available_only': '$availableOnly'});
    return rows.map((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      final now = DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now();
      final owner = User(id: row['owner_id'], name: '', email: '', phone: '', address: '', image: '', role: 'car_owner', createdAt: now, updatedAt: now, rating: 0, location: '', cars: const []);
      return Car(id: row['id'], brand: row['brand'], model: row['model'], year: row['year'], price: (row['price'] as num).toDouble(), currency: row['currency'], image: '', color: '', seats: 0, gearbox: '', fuel: '', mileage: 0, description: '', location: row['location'] ?? '', isAvailable: row['is_available'] == true || row['is_available'] == 1, createdAt: now, updatedAt: now, user: owner, ownerId: row['owner_id'], registrationNumber: '', reservedDates: const []);
    }).toList(growable: false);
  }
}

class RemoteNotificationRepository {
  RemoteNotificationRepository(this.api);
  final ApiClient api;

  Future<List<Map<String, dynamic>>> list(String userId, {bool unreadOnly = false}) async {
    final rows = await api.getList('/notifications', query: {'user_id': userId, 'unread_only': '$unreadOnly'});
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList(growable: false);
  }
}
