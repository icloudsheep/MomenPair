import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException({required this.code, required this.statusCode});

  final String code;
  final int statusCode;

  @override
  String toString() => 'ApiException($statusCode, $code)';
}

class ApiClient {
  ApiClient({
    required this.baseUri,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  final Uri baseUri;
  final http.Client _client;
  final Duration timeout;

  Future<Map<String, Object?>> get(
    String path, {
    String? accessToken,
  }) async {
    final response = await _client
        .get(
          baseUri.resolve(path),
          headers: _headers(accessToken),
        )
        .timeout(timeout);
    return _decodeMap(response);
  }

  Future<List<Map<String, Object?>>> getList(
    String path, {
    String? accessToken,
  }) async {
    final response = await _client
        .get(
          baseUri.resolve(path),
          headers: _headers(accessToken),
        )
        .timeout(timeout);
    final decoded = _decode(response);
    if (decoded is! List<Object?> ||
        decoded.any((item) => item is! Map<String, Object?>)) {
      throw ApiException(
        code: 'invalid_server_response',
        statusCode: response.statusCode,
      );
    }
    return decoded.cast<Map<String, Object?>>();
  }

  Future<Map<String, Object?>> post(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
  }) async {
    final response = await _client
        .post(
          baseUri.resolve(path),
          headers: _headers(accessToken),
          body: jsonEncode(body),
        )
        .timeout(timeout);
    return _decodeMap(response);
  }

  Future<Map<String, Object?>> patch(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
  }) async {
    final response = await _client
        .patch(
          baseUri.resolve(path),
          headers: _headers(accessToken),
          body: jsonEncode(body),
        )
        .timeout(timeout);
    return _decodeMap(response);
  }

  Future<Map<String, Object?>> delete(
    String path, {
    String? accessToken,
  }) async {
    final response = await _client
        .delete(
          baseUri.resolve(path),
          headers: _headers(accessToken),
        )
        .timeout(timeout);
    return _decodeMap(response);
  }

  Map<String, String> _headers(String? accessToken) => {
        'accept': 'application/json',
        'content-type': 'application/json; charset=utf-8',
        if (accessToken != null) 'authorization': 'Bearer $accessToken',
      };

  Map<String, Object?> _decodeMap(http.Response response) {
    final decoded = _decode(response);
    if (decoded is! Map<String, Object?>) {
      throw ApiException(
        code: 'invalid_server_response',
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  Object? _decode(http.Response response) {
    final Object? decoded = response.body.isEmpty
        ? <String, Object?>{}
        : jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    final detail = decoded is Map<String, Object?> ? decoded['detail'] : null;
    final code = detail is Map<String, Object?> && detail['code'] is String
        ? detail['code']! as String
        : 'request_failed';
    throw ApiException(code: code, statusCode: response.statusCode);
  }

  void close() => _client.close();
}
