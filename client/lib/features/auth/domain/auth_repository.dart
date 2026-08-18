import 'package:momen_pair_client/features/auth/domain/auth_models.dart';

abstract interface class AuthRepository {
  Future<AuthSession> loginWithCode(SocialProvider provider, String code);

  Future<AuthSession?> restore();

  Future<void> logout();
}
