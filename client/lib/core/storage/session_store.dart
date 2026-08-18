import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SessionStore {
  Future<String?> readRefreshToken();

  Future<void> writeRefreshToken(String value);

  Future<void> clearRefreshToken();

  Future<String> getOrCreateDeviceId();
}

class SecureSessionStore implements SessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _refreshTokenKey = 'momenpair.refresh_token';
  static const _deviceIdKey = 'momenpair.device_id';

  final FlutterSecureStorage _storage;

  @override
  Future<void> clearRefreshToken() => _storage.delete(key: _refreshTokenKey);

  @override
  Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    final deviceId = base64UrlEncode(bytes).replaceAll('=', '');
    await _storage.write(key: _deviceIdKey, value: deviceId);
    return deviceId;
  }

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  @override
  Future<void> writeRefreshToken(String value) =>
      _storage.write(key: _refreshTokenKey, value: value);
}
