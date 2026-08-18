import 'package:flutter_test/flutter_test.dart';
import 'package:momen_pair_client/core/network/api_client.dart';
import 'package:momen_pair_client/features/auth/domain/auth_models.dart';
import 'package:momen_pair_client/features/auth/domain/auth_repository.dart';
import 'package:momen_pair_client/features/auth/presentation/session_controller.dart';
import 'package:momen_pair_client/features/families/domain/family_models.dart';
import 'package:momen_pair_client/features/families/domain/family_repository.dart';
import 'package:momen_pair_client/features/families/presentation/family_controller.dart';

void main() {
  test(
    'returns a newly created code when invitation list refresh fails',
    () async {
      final controller = FamilyController(
        repository: _InvitationRefreshFailureRepository(),
        sessionController: _sessionController(),
      );

      final code = await controller.createInvitation();

      expect(code, 'one-time-code');
      expect(controller.errorCode, 'service_unavailable');
      expect(controller.busy, isFalse);
    },
  );

  test('keeps a created family visible when detail refresh fails', () async {
    final controller = FamilyController(
      repository: _FamilyRefreshFailureRepository(),
      sessionController: _sessionController(),
    );

    await controller.create('Home');

    expect(controller.family, _family);
    expect(controller.status, FamilyStatus.ready);
    expect(controller.errorCode, 'service_unavailable');
  });
}

SessionController _sessionController() => SessionController(
  repository: _UnusedAuthRepository(),
  initialSession: _session,
);

class _InvitationRefreshFailureRepository extends Fake
    implements FamilyRepository {
  @override
  Future<CreatedFamilyInvitation> createInvitation(String accessToken) async =>
      CreatedFamilyInvitation(invitation: _invitation, code: 'one-time-code');

  @override
  Future<List<FamilyInvitation>> getInvitations(String accessToken) {
    throw const ApiException(code: 'service_unavailable', statusCode: 503);
  }
}

class _FamilyRefreshFailureRepository extends Fake implements FamilyRepository {
  @override
  Future<FamilySummary> create(String accessToken, String name) async =>
      _family;

  @override
  Future<FamilySummary> getCurrent(String accessToken) {
    throw const ApiException(code: 'service_unavailable', statusCode: 503);
  }
}

class _UnusedAuthRepository extends Fake implements AuthRepository {}

const _user = AuthUser(
  id: 'user-id',
  displayName: 'User',
  provider: SocialProvider.wechat,
);
const _session = AuthSession(
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
  expiresIn: 900,
  user: _user,
);
const _family = FamilySummary(
  id: 'family-id',
  name: 'Home',
  role: FamilyRole.admin,
  memberCount: 1,
);
final _invitation = FamilyInvitation(
  id: 'invitation-id',
  expiresAt: DateTime.utc(2026, 8, 19),
  maxUses: 1,
  usedCount: 0,
  status: 'active',
);
