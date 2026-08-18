import 'package:momen_pair_client/core/network/api_client.dart';
import 'package:momen_pair_client/core/storage/session_store.dart';
import 'package:momen_pair_client/features/auth/domain/auth_models.dart';
import 'package:momen_pair_client/features/auth/domain/auth_repository.dart';

class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository(
      {required ApiClient apiClient, required SessionStore store})
      : _apiClient = apiClient,
        _store = store;

  final ApiClient _apiClient;
  final SessionStore _store;

  @override
  Future<AuthSession> loginWithCode(
    SocialProvider provider,
    String code,
  ) async {
    final deviceId = await _store.getOrCreateDeviceId();
    final json = await _apiClient.post(
      provider.apiPath,
      body: {'code': code, 'device_id': deviceId},
    );
    return _save(AuthSession.fromJson(json));
  }

  @override
  Future<AuthSession?> restore() async {
    final refreshToken = await _store.readRefreshToken();
    if (refreshToken == null) {
      return null;
    }
    try {
      final json = await _apiClient.post(
        'auth/refresh',
        body: {'refresh_token': refreshToken},
      );
      return await _save(AuthSession.fromJson(json));
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _store.clearRefreshToken();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    final refreshToken = await _store.readRefreshToken();
    try {
      if (refreshToken != null) {
        await _apiClient.post(
          'auth/logout',
          body: {'refresh_token': refreshToken},
        );
      }
    } finally {
      await _store.clearRefreshToken();
    }
  }

  Future<AuthSession> _save(AuthSession session) async {
    await _store.writeRefreshToken(session.refreshToken);
    return session;
  }
}
