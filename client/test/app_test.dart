import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momen_pair_client/app/app.dart';
import 'package:momen_pair_client/features/auth/domain/auth_models.dart';
import 'package:momen_pair_client/features/auth/domain/auth_repository.dart';
import 'package:momen_pair_client/features/auth/presentation/session_controller.dart';
import 'package:momen_pair_client/features/families/domain/family_models.dart';
import 'package:momen_pair_client/features/families/domain/family_repository.dart';
import 'package:momen_pair_client/features/families/presentation/family_controller.dart';
import 'package:momen_pair_client/features/logs/domain/log_models.dart';
import 'package:momen_pair_client/features/logs/domain/log_repository.dart';
import 'package:momen_pair_client/features/logs/presentation/log_controller.dart';

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
        logController: _createLogController(controller, familyController),
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
        logController: _createLogController(controller, familyController),
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
    final familyController = _createFamilyController(controller);
    await tester.pumpWidget(
      MomenPairApp(
        sessionController: controller,
        familyController: familyController,
        logController: _createLogController(controller, familyController),
        enableFakeSocialLogin: true,
        locale: const Locale('zh'),
      ),
    );

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('家庭空间'), findsOneWidget);
    expect(find.text('测试家庭'), findsOneWidget);
    expect(find.text('创建一次性邀请码'), findsOneWidget);
    expect(find.text('本地用户 (你)'), findsOneWidget);
  });
}

LogController _createLogController(
  SessionController sessionController,
  FamilyController familyController,
) {
  return LogController(
    repository: _FakeLogRepository(),
    sessionController: sessionController,
    familyController: familyController,
  );
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
    SocialProvider provider,
    String code,
  ) async {
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
      CreatedFamilyInvitation(invitation: _invitation, code: 'invitation-code');

  @override
  Future<FamilyMember> changeMemberRole(
    String accessToken,
    String userId,
    FamilyRole role,
  ) async => _member;

  @override
  Future<FamilySummary> getCurrent(String accessToken) async => _family;

  @override
  Future<List<FamilyInvitation>> getInvitations(String accessToken) async => [
    _invitation,
  ];

  @override
  Future<List<FamilyMember>> getMembers(String accessToken) async => [_member];

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

class _FakeLogRepository implements LogRepository {
  @override
  Future<FamilyLog> createLog(
    String accessToken, {
    required String requestId,
    required String title,
    String? subtitle,
    required String body,
    List<String> mediaIds = const [],
  }) async => _log;

  @override
  Future<LogComment> createComment(
    String accessToken,
    String logId, {
    required String requestId,
    String? title,
    required String body,
    String? replyToCommentId,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteComment(
    String accessToken,
    String logId,
    String commentId,
    int expectedVersion,
  ) async {}

  @override
  Future<void> deleteLog(
    String accessToken,
    String logId,
    int expectedVersion,
  ) async {}

  @override
  Future<List<LogComment>> getComments(
    String accessToken,
    String logId,
  ) async => const [];

  @override
  Future<FamilyLog> getLog(String accessToken, String logId) async => _log;

  @override
  Future<FamilyLogPage> getLogs(
    String accessToken, {
    String? cursor,
    int limit = 20,
  }) async => FamilyLogPage(items: [_log], nextCursor: null);

  @override
  Future<LogReaction> setLiked(
    String accessToken,
    String logId,
    bool liked,
  ) async => LogReaction(liked: liked, likeCount: liked ? 1 : 0);

  @override
  Future<FamilyLog> updateLog(
    String accessToken,
    String logId, {
    required int expectedVersion,
    required String title,
    String? subtitle,
    required String body,
    List<String> mediaIds = const [],
  }) async => _log;

  @override
  Future<LogMedia> uploadMedia(
    String accessToken, {
    required List<int> bytes,
    required String filename,
  }) => throw UnimplementedError();

  @override
  Future<void> deletePendingMedia(String accessToken, String mediaId) async {}
}

final _log = FamilyLog(
  id: 'log-id',
  authorUserId: 'user-id',
  authorDisplayName: '本地用户',
  title: '第一篇家庭日志',
  subtitle: null,
  body: '**今天** 一起吃饭。',
  version: 1,
  likeCount: 0,
  commentCount: 0,
  likedByMe: false,
  createdAt: DateTime.utc(2026, 8, 18),
  updatedAt: DateTime.utc(2026, 8, 18),
);
