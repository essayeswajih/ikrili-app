import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Web-compatible persistence for cached snapshots and pending commands.
/// SQLite remains the native cache; web uses this adapter until the remote API
/// is fully authoritative for every screen.
class WebCache {
  Future<void> write(String key, Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ikrili_cache_$key', jsonEncode(value));
  }

  Future<Map<String, dynamic>?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('ikrili_cache_$key');
    if (raw == null) return null;
    final value = jsonDecode(raw);
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ikrili_cache_$key');
  }
}
