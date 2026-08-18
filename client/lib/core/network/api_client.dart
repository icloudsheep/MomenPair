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

  Future<Map<String, Object?>> post(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
  }) async {
    final response = await _client
        .post(
          baseUri.resolve(path),
          headers: {
            'accept': 'application/json',
            'content-type': 'application/json; charset=utf-8',
            if (accessToken != null) 'authorization': 'Bearer $accessToken',
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);
    return _decode(response);
  }

  Map<String, Object?> _decode(http.Response response) {
    final Object? decoded = response.body.isEmpty
        ? <String, Object?>{}
        : jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, Object?>) {
      throw ApiException(
        code: 'invalid_server_response',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    final detail = decoded['detail'];
    final code = detail is Map<String, Object?> && detail['code'] is String
        ? detail['code']! as String
        : 'request_failed';
    throw ApiException(code: code, statusCode: response.statusCode);
  }

  void close() => _client.close();
}
