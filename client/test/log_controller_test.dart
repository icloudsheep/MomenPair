import 'package:flutter_test/flutter_test.dart';
import 'package:momen_pair_client/core/network/api_client.dart';
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
  test('loads cursor pages without duplicating overlapping entries', () async {
    final fixture = await _createFixture();

    await fixture.logs.load();
    await fixture.logs.loadMore();

    expect(fixture.logs.status, LogsStatus.ready);
    expect(fixture.logs.items.map((item) => item.id), [
      'log-1',
      'log-2',
      'log-3',
    ]);
    expect(fixture.logs.hasMore, isFalse);
  });

  test('keeps the original item when an edit has a version conflict', () async {
    final repository = _FakeLogRepository(failUpdateWithConflict: true);
    final fixture = await _createFixture(logRepository: repository);
    await fixture.logs.load();
    final original = fixture.logs.items.first;

    final result = await fixture.logs.update(
      original,
      title: 'Changed',
      body: 'Changed body',
    );

    expect(result, isNull);
    expect(fixture.logs.errorCode, 'log_version_conflict');
    expect(fixture.logs.items.first.title, original.title);
  });

  test('shows the family requirement instead of requesting logs', () async {
    final session = SessionController(
      repository: _FakeAuthRepository(),
      initialSession: _session,
    );
    final family = FamilyController(
      repository: _NoFamilyRepository(),
      sessionController: session,
    );
    final repository = _FakeLogRepository();
    final logs = LogController(
      repository: repository,
      sessionController: session,
      familyController: family,
    );

    await family.load();
    await logs.load();

    expect(logs.status, LogsStatus.noFamily);
    expect(repository.listCalls, 0);
  });

  test('reuses the idempotency key when the same draft is retried', () async {
    final repository = _FakeLogRepository(failFirstCreate: true);
    final fixture = await _createFixture(logRepository: repository);

    expect(await fixture.logs.create(title: 'Draft', body: 'Body'), isNull);
    expect(await fixture.logs.create(title: 'Draft', body: 'Body'), isNotNull);

    expect(repository.createRequestIds, hasLength(2));
    expect(repository.createRequestIds.toSet(), hasLength(1));
  });
}

Future<_Fixture> _createFixture({LogRepository? logRepository}) async {
  final session = SessionController(
    repository: _FakeAuthRepository(),
    initialSession: _session,
  );
  final family = FamilyController(
    repository: _FamilyRepository(),
    sessionController: session,
  );
  await family.load();
  final logs = LogController(
    repository: logRepository ?? _FakeLogRepository(),
    sessionController: session,
    familyController: family,
  );
  return _Fixture(logs: logs);
}

class _Fixture {
  const _Fixture({required this.logs});

  final LogController logs;
}

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

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthSession> loginWithCode(
    SocialProvider provider,
    String code,
  ) async => _session;

  @override
  Future<void> logout() async {}

  @override
  Future<AuthSession?> restore() async => _session;
}

class _FamilyRepository implements FamilyRepository {
  @override
  Future<FamilySummary> getCurrent(String accessToken) async => _family;

  @override
  Future<List<FamilyMember>> getMembers(String accessToken) async => [_member];

  @override
  Future<List<FamilyInvitation>> getInvitations(String accessToken) async => [];

  @override
  Future<FamilySummary> create(String accessToken, String name) async =>
      _family;

  @override
  Future<CreatedFamilyInvitation> createInvitation(String accessToken) =>
      throw UnimplementedError();

  @override
  Future<FamilyMember> changeMemberRole(
    String accessToken,
    String userId,
    FamilyRole role,
  ) => throw UnimplementedError();

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

class _NoFamilyRepository extends _FamilyRepository {
  @override
  Future<FamilySummary> getCurrent(String accessToken) =>
      throw const ApiException(code: 'family_not_found', statusCode: 404);
}

class _FakeLogRepository implements LogRepository {
  _FakeLogRepository({
    this.failUpdateWithConflict = false,
    this.failFirstCreate = false,
  });

  final bool failUpdateWithConflict;
  final bool failFirstCreate;
  int listCalls = 0;
  final List<String> createRequestIds = [];

  @override
  Future<FamilyLogPage> getLogs(
    String accessToken, {
    String? cursor,
    int limit = 20,
  }) async {
    listCalls += 1;
    return cursor == null
        ? FamilyLogPage(items: [_log1, _log2], nextCursor: 'next')
        : FamilyLogPage(items: [_log2, _log3], nextCursor: null);
  }

  @override
  Future<FamilyLog> updateLog(
    String accessToken,
    String logId, {
    required int expectedVersion,
    required String title,
    String? subtitle,
    required String body,
    List<String> mediaIds = const [],
  }) async {
    if (failUpdateWithConflict) {
      throw const ApiException(code: 'log_version_conflict', statusCode: 409);
    }
    return _log1;
  }

  @override
  Future<FamilyLog> createLog(
    String accessToken, {
    required String requestId,
    required String title,
    String? subtitle,
    required String body,
    List<String> mediaIds = const [],
  }) async {
    createRequestIds.add(requestId);
    if (failFirstCreate && createRequestIds.length == 1) {
      throw const ApiException(code: 'service_unavailable', statusCode: 503);
    }
    return _log1;
  }

  @override
  Future<LogMedia> uploadMedia(
    String accessToken, {
    required List<int> bytes,
    required String filename,
  }) => throw UnimplementedError();

  @override
  Future<void> deletePendingMedia(String accessToken, String mediaId) async {}

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
  ) async => [];

  @override
  Future<FamilyLog> getLog(String accessToken, String logId) async => _log1;

  @override
  Future<LogReaction> setLiked(
    String accessToken,
    String logId,
    bool liked,
  ) async => LogReaction(liked: liked, likeCount: liked ? 1 : 0);
}

const _family = FamilySummary(
  id: 'family-id',
  name: 'Home',
  role: FamilyRole.admin,
  memberCount: 1,
);
final _member = FamilyMember(
  userId: 'user-id',
  displayName: 'User',
  role: FamilyRole.admin,
  joinedAt: DateTime.utc(2026, 8, 18),
);

final _log1 = _log('log-1');
final _log2 = _log('log-2');
final _log3 = _log('log-3');

FamilyLog _log(String id) => FamilyLog(
  id: id,
  authorUserId: 'user-id',
  authorDisplayName: 'User',
  title: id,
  subtitle: null,
  body: 'Body',
  version: 1,
  likeCount: 0,
  commentCount: 0,
  likedByMe: false,
  createdAt: DateTime.utc(2026, 8, 18),
  updatedAt: DateTime.utc(2026, 8, 18),
);
