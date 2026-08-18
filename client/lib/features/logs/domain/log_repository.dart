import 'package:momen_pair_client/features/logs/domain/log_models.dart';

abstract interface class LogRepository {
  Future<FamilyLogPage> getLogs(
    String accessToken, {
    String? cursor,
    int limit = 20,
  });

  Future<FamilyLog> getLog(String accessToken, String logId);

  Future<FamilyLog> createLog(
    String accessToken, {
    required String requestId,
    required String title,
    String? subtitle,
    required String body,
    List<String> mediaIds = const [],
  });

  Future<FamilyLog> updateLog(
    String accessToken,
    String logId, {
    required int expectedVersion,
    required String title,
    String? subtitle,
    required String body,
    List<String> mediaIds = const [],
  });

  Future<LogMedia> uploadMedia(
    String accessToken, {
    required List<int> bytes,
    required String filename,
  });

  Future<void> deletePendingMedia(String accessToken, String mediaId);

  Future<void> deleteLog(String accessToken, String logId, int expectedVersion);

  Future<LogReaction> setLiked(String accessToken, String logId, bool liked);

  Future<List<LogComment>> getComments(String accessToken, String logId);

  Future<LogComment> createComment(
    String accessToken,
    String logId, {
    required String requestId,
    String? title,
    required String body,
    String? replyToCommentId,
  });

  Future<void> deleteComment(
    String accessToken,
    String logId,
    String commentId,
    int expectedVersion,
  );
}
