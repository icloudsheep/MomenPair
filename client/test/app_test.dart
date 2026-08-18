import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momen_pair_client/app/app.dart';
import 'package:momen_pair_client/features/auth/domain/auth_models.dart';
import 'package:momen_pair_client/features/auth/domain/auth_repository.dart';
import 'package:momen_pair_client/features/auth/presentation/session_controller.dart';
import 'package:momen_pair_client/features/families/domain/family_models.dart';
import 'package:momen_pair_client/features/families/domain/family_repository.dart';
import 'package:momen_pair_client/features/families/presentation/family_controller.dart';

void main() {
  testWidgets('shows the five primary destinations', (tester) async {
    final controller = SessionController(
      repository: _FakeAuthRepository(),
      initialSession: _session,
    );
    final familyController = _createFamilyController(controller);
    await tester.pumpWidget(
      MomenPairApp(
        sessionController: controller,
        familyController: familyController,
        enableFakeSocialLogin: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byIcon(Icons.auto_stories), findsWidgets);
    expect(find.byIcon(Icons.campaign_outlined), findsOneWidget);
    expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
  });

  testWidgets('shows independent WeChat and QQ login choices', (tester) async {
    final controller = SessionController(repository: _FakeAuthRepository());
    final familyController = _createFamilyController(controller);
    await controller.restore();
    await tester.pumpWidget(
      MomenPairApp(
        sessionController: controller,
        familyController: familyController,
        enableFakeSocialLogin: true,
        locale: const Locale('zh'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('使用微信登录'), findsOneWidget);
    expect(find.text('使用 QQ 登录'), findsOneWidget);
    expect(find.textContaining('两个独立账号'), findsOneWidget);
  });

  testWidgets('shows current family and member management', (tester) async {
    final controller = SessionController(
      repository: _FakeAuthRepository(),
      initialSession: _session,
    );
    await tester.pumpWidget(
      MomenPairApp(
        sessionController: controller,
        familyController: _createFamilyController(controller),
        enableFakeSocialLogin: true,
        locale: const Locale('zh'),
      ),
    );

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(CustomScrollView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    expect(find.text('家庭空间'), findsOneWidget);
    expect(find.text('测试家庭'), findsOneWidget);
    expect(find.text('创建一次性邀请码'), findsOneWidget);
    expect(find.text('本地用户 (你)'), findsOneWidget);
  });
}

const _user = AuthUser(
  id: 'user-id',
  displayName: '本地用户',
  provider: SocialProvider.wechat,
);
const _session = AuthSession(
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
  expiresIn: 900,
  user: _user,
);

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthSession> loginWithCode(
      SocialProvider provider, String code) async {
    return _session;
  }

  @override
  Future<void> logout() async {}

  @override
  Future<AuthSession?> restore() async => null;
}

FamilyController _createFamilyController(SessionController sessionController) {
  return FamilyController(
    repository: _FakeFamilyRepository(),
    sessionController: sessionController,
  );
}

class _FakeFamilyRepository implements FamilyRepository {
  @override
  Future<FamilySummary> create(String accessToken, String name) async =>
      _family;

  @override
  Future<CreatedFamilyInvitation> createInvitation(String accessToken) async =>
      CreatedFamilyInvitation(
        invitation: _invitation,
        code: 'invitation-code',
      );

  @override
  Future<FamilyMember> changeMemberRole(
    String accessToken,
    String userId,
    FamilyRole role,
  ) async =>
      _member;

  @override
  Future<FamilySummary> getCurrent(String accessToken) async => _family;

  @override
  Future<List<FamilyInvitation>> getInvitations(String accessToken) async =>
      [_invitation];

  @override
  Future<List<FamilyMember>> getMembers(String accessToken) async => [
        _member,
      ];

  @override
  Future<FamilySummary> join(String accessToken, String code) async => _family;

  @override
  Future<void> leave(String accessToken) async {}

  @override
  Future<void> removeMember(String accessToken, String userId) async {}

  @override
  Future<void> revokeInvitation(
    String accessToken,
    String invitationId,
  ) async {}
}

const _family = FamilySummary(
  id: 'family-id',
  name: '测试家庭',
  role: FamilyRole.admin,
  memberCount: 1,
);
final _member = FamilyMember(
  userId: 'user-id',
  displayName: '本地用户',
  role: FamilyRole.admin,
  joinedAt: DateTime.utc(2026, 8, 18),
);
final _invitation = FamilyInvitation(
  id: 'invitation-id',
  expiresAt: DateTime.utc(2026, 8, 19),
  maxUses: 1,
  usedCount: 0,
  status: 'active',
);
