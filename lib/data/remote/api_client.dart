import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import 'api_exception.dart';
import 'token_store.dart';

class ApiClient {
  ApiClient({http.Client? client, TokenStore? tokens})
      : _client = client ?? http.Client(),
        _tokens = tokens ?? TokenStore.instance;

  final http.Client _client;
  final TokenStore _tokens;

  Future<Map<String, dynamic>> getJson(String path, {Map<String, String>? query}) async {
    final response = await _send(() => _client.get(_uri(path, query), headers: _headers()));
    return _decodeMap(response);
  }

  Future<List<dynamic>> getList(String path, {Map<String, String>? query}) async {
    final response = await _send(() => _client.get(_uri(path, query), headers: _headers()));
    final value = _decode(response);
    if (value is! List) throw const ApiException(500, 'Invalid list response');
    return value;
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final response = await _send(() => _client.post(_uri(path), headers: _headers(), body: jsonEncode(body)));
    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) async {
    final response = await _send(() => _client.patch(_uri(path), headers: _headers(), body: jsonEncode(body)));
    return _decodeMap(response);
  }

  Uri _uri(String path, [Map<String, String>? query]) => Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: query);

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        if (_tokens.accessToken != null) 'Authorization': 'Bearer ${_tokens.accessToken}',
      };

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = _decode(response);
        throw ApiException(response.statusCode, body is Map ? (body['detail']?.toString() ?? 'Request failed') : 'Request failed');
      }
      return response;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(0, 'Network unavailable. Cached data is being used.');
    }
  }

  dynamic _decode(http.Response response) {
    if (response.body.isEmpty) return <String, dynamic>{};
    try { return jsonDecode(response.body); } catch (_) { return response.body; }
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    final value = _decode(response);
    if (value is! Map) throw const ApiException(500, 'Invalid object response');
    return Map<String, dynamic>.from(value);
  }
}
