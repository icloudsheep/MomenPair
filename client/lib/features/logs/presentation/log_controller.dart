import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:momen_pair_client/core/network/api_client.dart';
import 'package:momen_pair_client/features/auth/presentation/session_controller.dart';
import 'package:momen_pair_client/features/families/presentation/family_controller.dart';
import 'package:momen_pair_client/features/logs/domain/log_models.dart';
import 'package:momen_pair_client/features/logs/domain/log_repository.dart';

enum LogsStatus { idle, loading, noFamily, ready, error }

class LogController extends ChangeNotifier {
  LogController({
    required LogRepository repository,
    required SessionController sessionController,
    required FamilyController familyController,
    Uri? apiBaseUri,
  }) : _repository = repository,
       _sessionController = sessionController,
       _familyController = familyController,
       _apiBaseUri = apiBaseUri ?? Uri.parse('http://localhost/api/v1/') {
    _sessionController.addListener(_handleContextChange);
    _familyController.addListener(_handleContextChange);
  }

  final LogRepository _repository;
  final SessionController _sessionController;
  final FamilyController _familyController;
  final Uri _apiBaseUri;
  final Random _random = Random.secure();

  LogsStatus _status = LogsStatus.idle;
  List<FamilyLog> _items = const [];
  String? _nextCursor;
  String? _errorCode;
  String? _loadedContext;
  bool _busy = false;
  bool _loadingMore = false;
  String? _pendingCreateRequestId;
  String? _pendingCreateTitle;
  String? _pendingCreateSubtitle;
  String? _pendingCreateBody;
  List<String>? _pendingCreateMediaIds;

  LogsStatus get status => _status;
  List<FamilyLog> get items => _items;
  String? get errorCode => _errorCode;
  bool get busy => _busy;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _nextCursor != null;
  Map<String, String> get mediaHeaders => {
    if (_accessToken case final token?) 'authorization': 'Bearer $token',
  };

  Uri mediaUri(LogMedia media) => _apiBaseUri.resolve(media.contentUrl);

  void sync() {
    _familyController.sync();
    final contextKey = _contextKey;
    if (_familyController.status == FamilyStatus.noFamily) {
      if (_status != LogsStatus.noFamily) {
        _resetContent(LogsStatus.noFamily);
        notifyListeners();
      }
      return;
    }
    if (contextKey != null && contextKey != _loadedContext) {
      unawaited(load());
    }
  }

  Future<void> load() async {
    final token = _accessToken;
    final contextKey = _contextKey;
    if (token == null) {
      _resetContent(LogsStatus.idle);
      notifyListeners();
      return;
    }
    if (_familyController.status == FamilyStatus.noFamily) {
      _resetContent(LogsStatus.noFamily);
      notifyListeners();
      return;
    }
    if (contextKey == null) {
      _status = LogsStatus.loading;
      notifyListeners();
      return;
    }
    _status = LogsStatus.loading;
    _errorCode = null;
    notifyListeners();
    try {
      final page = await _repository.getLogs(token);
      if (_contextKey != contextKey) {
        return;
      }
      _items = page.items;
      _nextCursor = page.nextCursor;
      _loadedContext = contextKey;
      _status = LogsStatus.ready;
    } on ApiException catch (error) {
      _applyError(error.code);
    } on Object {
      _applyError('service_unavailable');
    }
    notifyListeners();
  }

  Future<void> loadMore() async {
    final token = _accessToken;
    final cursor = _nextCursor;
    if (token == null || cursor == null || _loadingMore) {
      return;
    }
    _loadingMore = true;
    _errorCode = null;
    notifyListeners();
    try {
      final page = await _repository.getLogs(token, cursor: cursor);
      final knownIds = _items.map((item) => item.id).toSet();
      _items = [
        ..._items,
        ...page.items.where((item) => knownIds.add(item.id)),
      ];
      _nextCursor = page.nextCursor;
    } on ApiException catch (error) {
      _errorCode = error.code;
    } on Object {
      _errorCode = 'service_unavailable';
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<FamilyLog?> create({
    required String title,
    String? subtitle,
    required String body,
    List<String> mediaIds = const [],
  }) async {
    final token = _accessToken;
    if (token == null || _busy) {
      return null;
    }
    final normalizedTitle = title.trim();
    final normalizedSubtitle = _optional(subtitle);
    final normalizedBody = body.trim();
    if (_pendingCreateRequestId == null ||
        _pendingCreateTitle != normalizedTitle ||
        _pendingCreateSubtitle != normalizedSubtitle ||
        _pendingCreateBody != normalizedBody ||
        !listEquals(_pendingCreateMediaIds, mediaIds)) {
      _pendingCreateRequestId = _newRequestId();
      _pendingCreateTitle = normalizedTitle;
      _pendingCreateSubtitle = normalizedSubtitle;
      _pendingCreateBody = normalizedBody;
      _pendingCreateMediaIds = List.unmodifiable(mediaIds);
    }
    _startAction();
    try {
      final created = await _repository.createLog(
        token,
        requestId: _pendingCreateRequestId!,
        title: normalizedTitle,
        subtitle: normalizedSubtitle,
        body: normalizedBody,
        mediaIds: mediaIds,
      );
      _items = [created, ..._items];
      _status = LogsStatus.ready;
      _clearPendingCreate();
      return created;
    } on ApiException catch (error) {
      _errorCode = error.code;
      return null;
    } on Object {
      _errorCode = 'service_unavailable';
      return null;
    } finally {
      _finishAction();
    }
  }

  Future<FamilyLog?> update(
    FamilyLog item, {
    required String title,
    String? subtitle,
    required String body,
    List<String> mediaIds = const [],
  }) async {
    final token = _accessToken;
    if (token == null || _busy) {
      return null;
    }
    _startAction();
    try {
      final updated = await _repository.updateLog(
        token,
        item.id,
        expectedVersion: item.version,
        title: title.trim(),
        subtitle: _optional(subtitle),
        body: body.trim(),
        mediaIds: mediaIds,
      );
      _replace(updated);
      return updated;
    } on ApiException catch (error) {
      _errorCode = error.code;
      return null;
    } on Object {
      _errorCode = 'service_unavailable';
      return null;
    } finally {
      _finishAction();
    }
  }

  Future<LogMedia?> uploadMedia({
    required List<int> bytes,
    required String filename,
  }) async {
    final token = _accessToken;
    if (token == null) {
      return null;
    }
    try {
      return await _repository.uploadMedia(
        token,
        bytes: bytes,
        filename: filename,
      );
    } on ApiException catch (error) {
      _errorCode = error.code;
      notifyListeners();
      return null;
    } on Object {
      _errorCode = 'service_unavailable';
      notifyListeners();
      return null;
    }
  }

  Future<void> discardPendingMedia(LogMedia media) async {
    final token = _accessToken;
    if (token == null) {
      return;
    }
    try {
      await _repository.deletePendingMedia(token, media.id);
    } on Object {
      // Pending uploads expire server-side if immediate cleanup cannot complete.
    }
  }

  Future<bool> delete(FamilyLog item) async {
    final token = _accessToken;
    if (token == null || _busy) {
      return false;
    }
    _startAction();
    try {
      await _repository.deleteLog(token, item.id, item.version);
      _items = _items.where((candidate) => candidate.id != item.id).toList();
      return true;
    } on ApiException catch (error) {
      _errorCode = error.code;
      return false;
    } on Object {
      _errorCode = 'service_unavailable';
      return false;
    } finally {
      _finishAction();
    }
  }

  Future<void> toggleLike(FamilyLog item) async {
    final token = _accessToken;
    if (token == null) {
      return;
    }
    try {
      final reaction = await _repository.setLiked(
        token,
        item.id,
        !item.likedByMe,
      );
      _replace(
        item.withReaction(liked: reaction.liked, count: reaction.likeCount),
      );
      notifyListeners();
    } on ApiException catch (error) {
      _errorCode = error.code;
      notifyListeners();
    } on Object {
      _errorCode = 'service_unavailable';
      notifyListeners();
    }
  }

  Future<List<LogComment>?> getComments(String logId) async {
    final token = _accessToken;
    if (token == null) {
      return null;
    }
    try {
      return await _repository.getComments(token, logId);
    } on ApiException catch (error) {
      _errorCode = error.code;
      notifyListeners();
      return null;
    } on Object {
      _errorCode = 'service_unavailable';
      notifyListeners();
      return null;
    }
  }

  Future<LogComment?> addComment(
    FamilyLog item, {
    required String body,
    String? replyToCommentId,
  }) async {
    final token = _accessToken;
    if (token == null || _busy) {
      return null;
    }
    _startAction();
    try {
      final comment = await _repository.createComment(
        token,
        item.id,
        requestId: _newRequestId(),
        body: body.trim(),
        replyToCommentId: replyToCommentId,
      );
      final refreshed = await _repository.getLog(token, item.id);
      _replace(refreshed);
      return comment;
    } on ApiException catch (error) {
      _errorCode = error.code;
      return null;
    } on Object {
      _errorCode = 'service_unavailable';
      return null;
    } finally {
      _finishAction();
    }
  }

  Future<bool> deleteComment(FamilyLog item, LogComment comment) async {
    final token = _accessToken;
    if (token == null || _busy) {
      return false;
    }
    _startAction();
    try {
      await _repository.deleteComment(
        token,
        item.id,
        comment.id,
        comment.version,
      );
      _replace(await _repository.getLog(token, item.id));
      return true;
    } on ApiException catch (error) {
      _errorCode = error.code;
      return false;
    } on Object {
      _errorCode = 'service_unavailable';
      return false;
    } finally {
      _finishAction();
    }
  }

  void clearError() {
    if (_errorCode == null) {
      return;
    }
    _errorCode = null;
    notifyListeners();
  }

  void _replace(FamilyLog item) {
    _items = [
      for (final candidate in _items)
        if (candidate.id == item.id) item else candidate,
    ];
  }

  void _startAction() {
    _busy = true;
    _errorCode = null;
    notifyListeners();
  }

  void _finishAction() {
    _busy = false;
    notifyListeners();
  }

  void _applyError(String code) {
    if (code == 'family_required') {
      _resetContent(LogsStatus.noFamily);
    } else {
      _status = LogsStatus.error;
      _errorCode = code;
    }
  }

  void _handleContextChange() {
    final contextKey = _contextKey;
    if (contextKey == null && _loadedContext != null) {
      _resetContent(
        _familyController.status == FamilyStatus.noFamily
            ? LogsStatus.noFamily
            : LogsStatus.idle,
      );
      notifyListeners();
      return;
    }
    if (contextKey != null && contextKey != _loadedContext) {
      unawaited(load());
    }
  }

  void _resetContent(LogsStatus status) {
    _items = const [];
    _nextCursor = null;
    _errorCode = null;
    _loadedContext = null;
    _busy = false;
    _loadingMore = false;
    _clearPendingCreate();
    _status = status;
  }

  void _clearPendingCreate() {
    _pendingCreateRequestId = null;
    _pendingCreateTitle = null;
    _pendingCreateSubtitle = null;
    _pendingCreateBody = null;
    _pendingCreateMediaIds = null;
  }

  String _newRequestId() {
    final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final entropy = _random.nextInt(0x7fffffff).toRadixString(36);
    return '$time-$entropy';
  }

  String? _optional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  String? get _accessToken => _sessionController.session?.accessToken;

  String? get _contextKey {
    final userId = _sessionController.session?.user.id;
    final familyId = _familyController.family?.id;
    if (userId == null ||
        familyId == null ||
        _familyController.status != FamilyStatus.ready) {
      return null;
    }
    return '$userId:$familyId';
  }

  @override
  void dispose() {
    _sessionController.removeListener(_handleContextChange);
    _familyController.removeListener(_handleContextChange);
    super.dispose();
  }
}
