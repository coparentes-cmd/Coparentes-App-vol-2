import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client_factory.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? data;

  const ApiException(this.statusCode, this.message, {this.data});

  @override
  String toString() => 'ApiException($statusCode, $message)';
}

class AppApiClient {
  static const _requestTimeout = Duration(seconds: 12);

  final String baseUrl;
  final http.Client _httpClient;
  String? _token;
  String? _trustedDeviceToken;

  AppApiClient({
    required this.baseUrl,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? createApiHttpClient();

  void setToken(String? token) {
    _token = token;
  }

  void setTrustedDeviceToken(String? token) {
    _trustedDeviceToken = token;
  }

  void dispose() {
    _httpClient.close();
  }

  bool isNetworkError(Object error) => error is! ApiException;

  Future<Map<String, dynamic>> getJson(String path) async {
    final response = await _httpClient
        .get(
          Uri.parse('$baseUrl$path'),
          headers: _headers(),
        )
        .timeout(_requestTimeout);
    return _decode(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    Duration? timeout,
    Map<String, String>? extraHeaders,
  }) async {
    final response = await _httpClient
        .post(
          Uri.parse('$baseUrl$path'),
          headers: _headers(extra: extraHeaders),
          body: jsonEncode(body),
        )
        .timeout(timeout ?? _requestTimeout);
    return _decode(response);
  }

  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _httpClient
        .patch(
          Uri.parse('$baseUrl$path'),
          headers: _headers(),
          body: jsonEncode(body),
        )
        .timeout(_requestTimeout);
    return _decode(response);
  }

  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _httpClient
        .put(
          Uri.parse('$baseUrl$path'),
          headers: _headers(),
          body: jsonEncode(body),
        )
        .timeout(_requestTimeout);
    return _decode(response);
  }

  Future<void> postEmpty(String path) async {
    final response = await _httpClient
        .post(
          Uri.parse('$baseUrl$path'),
          headers: _headers(),
        )
        .timeout(_requestTimeout);
    if (response.statusCode >= 400) {
      throw ApiException(response.statusCode, _parseError(response.body));
    }
  }

  Future<bool> pingHealth() async {
    try {
      final healthBaseUrl = baseUrl.endsWith('/api')
          ? baseUrl.substring(0, baseUrl.length - 4)
          : baseUrl;

      final response = await _httpClient
          .get(Uri.parse('$healthBaseUrl/health'))
          .timeout(const Duration(seconds: 8));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Map<String, String> _headers({Map<String, String>? extra}) {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
      if (_trustedDeviceToken != null && _trustedDeviceToken!.isNotEmpty)
        'X-Trusted-Device-Token': _trustedDeviceToken!,
      ...?extra,
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    dynamic decoded;
    if (response.body.isEmpty) {
      decoded = <String, dynamic>{};
    } else {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        throw ApiException(response.statusCode, 'invalid_json');
      }
    }

    if (decoded is! Map<String, dynamic>) {
      if (decoded is Map) {
        decoded = Map<String, dynamic>.from(decoded);
      } else {
        throw ApiException(response.statusCode, 'invalid_response');
      }
    }

    final data = decoded;

    if (response.statusCode >= 400) {
      final message = data['error'] as String? ?? 'request_failed';
      throw ApiException(response.statusCode, message, data: data);
    }
    return data;
  }

  String _parseError(String body) {
    if (body.isEmpty) {
      return 'request_failed';
    }

    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['error'] as String? ?? 'request_failed';
    } catch (_) {
      return 'request_failed';
    }
  }
}
