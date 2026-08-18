class FamilyLog {
  const FamilyLog({
    required this.id,
    required this.authorUserId,
    required this.authorDisplayName,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.version,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
    this.media = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory FamilyLog.fromJson(Map<String, Object?> json) {
    return FamilyLog(
      id: json['id']! as String,
      authorUserId: json['author_user_id']! as String,
      authorDisplayName: json['author_display_name']! as String,
      title: json['title']! as String,
      subtitle: json['subtitle'] as String?,
      body: json['body']! as String,
      version: json['version']! as int,
      likeCount: json['like_count']! as int,
      commentCount: json['comment_count']! as int,
      likedByMe: json['liked_by_me']! as bool,
      media: (json['media'] as List<Object?>? ?? const [])
          .cast<Map<String, Object?>>()
          .map(LogMedia.fromJson)
          .toList(growable: false),
      createdAt: DateTime.parse(json['created_at']! as String).toUtc(),
      updatedAt: DateTime.parse(json['updated_at']! as String).toUtc(),
    );
  }

  final String id;
  final String authorUserId;
  final String authorDisplayName;
  final String title;
  final String? subtitle;
  final String body;
  final int version;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final List<LogMedia> media;
  final DateTime createdAt;
  final DateTime updatedAt;

  FamilyLog withReaction({required bool liked, required int count}) {
    return FamilyLog(
      id: id,
      authorUserId: authorUserId,
      authorDisplayName: authorDisplayName,
      title: title,
      subtitle: subtitle,
      body: body,
      version: version,
      likeCount: count,
      commentCount: commentCount,
      likedByMe: liked,
      media: media,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class LogMedia {
  const LogMedia({
    required this.id,
    required this.contentType,
    required this.width,
    required this.height,
    required this.byteSize,
    required this.contentUrl,
  });

  factory LogMedia.fromJson(Map<String, Object?> json) => LogMedia(
    id: json['id']! as String,
    contentType: json['content_type']! as String,
    width: json['width']! as int,
    height: json['height']! as int,
    byteSize: json['byte_size']! as int,
    contentUrl: json['content_url']! as String,
  );

  final String id;
  final String contentType;
  final int width;
  final int height;
  final int byteSize;
  final String contentUrl;
}

class FamilyLogPage {
  const FamilyLogPage({required this.items, required this.nextCursor});

  factory FamilyLogPage.fromJson(Map<String, Object?> json) {
    final rawItems = json['items']! as List<Object?>;
    return FamilyLogPage(
      items: rawItems
          .cast<Map<String, Object?>>()
          .map(FamilyLog.fromJson)
          .toList(growable: false),
      nextCursor: json['next_cursor'] as String?,
    );
  }

  final List<FamilyLog> items;
  final String? nextCursor;
}

class LogReaction {
  const LogReaction({required this.liked, required this.likeCount});

  factory LogReaction.fromJson(Map<String, Object?> json) {
    return LogReaction(
      liked: json['liked']! as bool,
      likeCount: json['like_count']! as int,
    );
  }

  final bool liked;
  final int likeCount;
}

class LogComment {
  const LogComment({
    required this.id,
    required this.authorUserId,
    required this.authorDisplayName,
    required this.rootCommentId,
    required this.replyToCommentId,
    required this.title,
    required this.body,
    required this.version,
    required this.deleted,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LogComment.fromJson(Map<String, Object?> json) {
    return LogComment(
      id: json['id']! as String,
      authorUserId: json['author_user_id']! as String,
      authorDisplayName: json['author_display_name']! as String,
      rootCommentId: json['root_comment_id'] as String?,
      replyToCommentId: json['reply_to_comment_id'] as String?,
      title: json['title'] as String?,
      body: json['body'] as String?,
      version: json['version']! as int,
      deleted: json['deleted']! as bool,
      createdAt: DateTime.parse(json['created_at']! as String).toUtc(),
      updatedAt: DateTime.parse(json['updated_at']! as String).toUtc(),
    );
  }

  final String id;
  final String authorUserId;
  final String authorDisplayName;
  final String? rootCommentId;
  final String? replyToCommentId;
  final String? title;
  final String? body;
  final int version;
  final bool deleted;
  final DateTime createdAt;
  final DateTime updatedAt;
}
