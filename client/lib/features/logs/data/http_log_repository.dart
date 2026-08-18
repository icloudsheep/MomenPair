import 'package:momen_pair_client/core/network/api_client.dart';
import 'package:momen_pair_client/features/logs/domain/log_models.dart';
import 'package:momen_pair_client/features/logs/domain/log_repository.dart';

class HttpLogRepository implements LogRepository {
  const HttpLogRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<FamilyLogPage> getLogs(
    String accessToken, {
    String? cursor,
    int limit = 20,
  }) async {
    final query = Uri(
      queryParameters: {
        'limit': '$limit',
        if (cursor != null) 'cursor': cursor,
      },
    ).query;
    final json = await _apiClient.get('logs?$query', accessToken: accessToken);
    return FamilyLogPage.fromJson(json);
  }

  @override
  Future<FamilyLog> getLog(String accessToken, String logId) async {
    final json = await _apiClient.get('logs/$logId', accessToken: accessToken);
    return FamilyLog.fromJson(json);
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
    final json = await _apiClient.post(
      'logs',
      body: {
        'title': title,
        'subtitle': subtitle,
        'body': body,
        'media_ids': mediaIds,
      },
      accessToken: accessToken,
      headers: {'Idempotency-Key': requestId},
    );
    return FamilyLog.fromJson(json);
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
    final json = await _apiClient.patch(
      'logs/$logId',
      body: {
        'expected_version': expectedVersion,
        'title': title,
        'subtitle': subtitle,
        'body': body,
        'media_ids': mediaIds,
      },
      accessToken: accessToken,
    );
    return FamilyLog.fromJson(json);
  }

  @override
  Future<LogMedia> uploadMedia(
    String accessToken, {
    required List<int> bytes,
    required String filename,
  }) async {
    final json = await _apiClient.postMultipart(
      'logs/media',
      bytes: bytes,
      filename: filename,
      field: 'image',
      accessToken: accessToken,
    );
    return LogMedia.fromJson(json);
  }

  @override
  Future<void> deletePendingMedia(String accessToken, String mediaId) async {
    await _apiClient.delete('logs/media/$mediaId', accessToken: accessToken);
  }

  @override
  Future<void> deleteLog(
    String accessToken,
    String logId,
    int expectedVersion,
  ) async {
    await _apiClient.delete(
      'logs/$logId?expected_version=$expectedVersion',
      accessToken: accessToken,
    );
  }

  @override
  Future<LogReaction> setLiked(
    String accessToken,
    String logId,
    bool liked,
  ) async {
    final json = liked
        ? await _apiClient.put('logs/$logId/like', accessToken: accessToken)
        : await _apiClient.delete('logs/$logId/like', accessToken: accessToken);
    return LogReaction.fromJson(json);
  }

  @override
  Future<List<LogComment>> getComments(String accessToken, String logId) async {
    final json = await _apiClient.getList(
      'logs/$logId/comments',
      accessToken: accessToken,
    );
    return json.map(LogComment.fromJson).toList(growable: false);
  }

  @override
  Future<LogComment> createComment(
    String accessToken,
    String logId, {
    required String requestId,
    String? title,
    required String body,
    String? replyToCommentId,
  }) async {
    final json = await _apiClient.post(
      'logs/$logId/comments',
      body: {
        'title': title,
        'body': body,
        'reply_to_comment_id': replyToCommentId,
      },
      accessToken: accessToken,
      headers: {'Idempotency-Key': requestId},
    );
    return LogComment.fromJson(json);
  }

  @override
  Future<void> deleteComment(
    String accessToken,
    String logId,
    String commentId,
    int expectedVersion,
  ) async {
    await _apiClient.delete(
      'logs/$logId/comments/$commentId?expected_version=$expectedVersion',
      accessToken: accessToken,
    );
  }
}
