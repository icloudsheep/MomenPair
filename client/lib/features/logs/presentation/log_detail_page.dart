import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:momen_pair_client/features/logs/domain/log_models.dart';
import 'package:momen_pair_client/features/logs/presentation/log_controller.dart';
import 'package:momen_pair_client/features/logs/presentation/log_editor_page.dart';
import 'package:momen_pair_client/features/logs/presentation/log_scope.dart';
import 'package:momen_pair_client/features/logs/presentation/log_visuals.dart';
import 'package:momen_pair_client/l10n/generated/app_localizations.dart';

class LogDetailPage extends StatefulWidget {
  const LogDetailPage({
    required this.initialItem,
    required this.currentUserId,
    super.key,
  });

  final FamilyLog initialItem;
  final String? currentUserId;

  @override
  State<LogDetailPage> createState() => _LogDetailPageState();
}

class _LogDetailPageState extends State<LogDetailPage> {
  late FamilyLog _item;
  List<LogComment>? _comments;
  bool _loadingComments = true;

  @override
  void initState() {
    super.initState();
    _item = widget.initialItem;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadComments());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = LogScope.of(context);
    final isAuthor = widget.currentUserId == _item.authorUserId;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(l10n.logDetailTitle),
        actions: [
          if (isAuthor)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _edit(controller);
                } else if (value == 'delete') {
                  _delete(controller);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(l10n.editLog)),
                PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
              ],
            ),
        ],
      ),
      body: LogBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
          children: [
            Text(
              _item.title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (_item.subtitle case final subtitle?) ...[
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              '${_item.authorDisplayName} · ${formatLogTime(context, _item.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 18),
            LogGlassSurface(child: LogMarkdownBody(data: _item.body)),
            if (_item.media.isNotEmpty) ...[
              const SizedBox(height: 12),
              LogGlassSurface(
                padding: const EdgeInsets.all(10),
                child: LogMediaGallery(
                  media: _item.media,
                  controller: controller,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: () async {
                    await controller.toggleLike(_item);
                    _syncItem(controller);
                  },
                  icon: Icon(
                    _item.likedByMe ? Icons.favorite : Icons.favorite_border,
                  ),
                  label: Text(l10n.likesCount(_item.likeCount)),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _composeComment(controller),
                  icon: const Icon(Icons.add_comment_outlined),
                  label: Text(l10n.addComment),
                ),
              ],
            ),
            const SizedBox(height: 26),
            Text(
              l10n.commentsTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            if (_loadingComments)
              const Center(child: CircularProgressIndicator())
            else if (_comments == null)
              TextButton.icon(
                onPressed: _loadComments,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              )
            else if (_comments!.isEmpty)
              Text(
                l10n.commentsEmpty,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.64),
                ),
              )
            else
              for (final comment in _comments!)
                _CommentPanel(
                  comment: comment,
                  onReply: comment.deleted
                      ? null
                      : () => _composeComment(controller, replyTo: comment),
                  onDelete: comment.authorUserId == widget.currentUserId
                      ? () => _deleteComment(controller, comment)
                      : null,
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    final comments = await LogScope.of(context).getComments(_item.id);
    if (mounted) {
      setState(() {
        _comments = comments;
        _loadingComments = false;
      });
    }
  }

  Future<void> _edit(LogController controller) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LogScope(
          controller: controller,
          child: LogEditorPage(item: _item),
        ),
      ),
    );
    _syncItem(controller);
  }

  Future<void> _delete(LogController controller) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(l10n.deleteLogTitle),
        content: Text(l10n.deleteLogDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true && await controller.delete(_item) && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _composeComment(
    LogController controller, {
    LogComment? replyTo,
  }) async {
    final l10n = AppLocalizations.of(context);
    final input = TextEditingController();
    final body = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          replyTo == null
              ? l10n.addComment
              : l10n.replyTo(replyTo.authorDisplayName),
        ),
        content: TextField(
          controller: input,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          maxLength: 10000,
          decoration: InputDecoration(
            hintText: l10n.commentHint,
            hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.58),
              fontSize: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final value = input.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(context, value);
              }
            },
            child: Text(l10n.send),
          ),
        ],
      ),
    );
    input.dispose();
    if (body == null) {
      return;
    }
    final created = await controller.addComment(
      _item,
      body: body,
      replyToCommentId: replyTo?.id,
    );
    if (created != null) {
      _syncItem(controller);
      await _loadComments();
    }
  }

  Future<void> _deleteComment(
    LogController controller,
    LogComment comment,
  ) async {
    if (await controller.deleteComment(_item, comment)) {
      _syncItem(controller);
      await _loadComments();
    }
  }

  void _syncItem(LogController controller) {
    final matches = controller.items.where((item) => item.id == _item.id);
    if (matches.isNotEmpty && mounted) {
      setState(() => _item = matches.first);
    }
  }
}

class _CommentPanel extends StatelessWidget {
  const _CommentPanel({required this.comment, this.onReply, this.onDelete});

  final LogComment comment;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        top: 10,
        left: comment.rootCommentId == null ? 0 : 24,
      ),
      child: LogGlassSurface(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 8),
        radius: 12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    comment.authorDisplayName,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Text(
                  formatLogTime(context, comment.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (comment.deleted)
              Text(
                l10n.deletedComment,
                style: TextStyle(color: colors.onSurfaceVariant),
              )
            else
              LogMarkdownBody(data: comment.body!),
            if (!comment.deleted || onDelete != null)
              Wrap(
                spacing: 2,
                children: [
                  if (onReply != null)
                    TextButton(onPressed: onReply, child: Text(l10n.reply)),
                  if (onDelete != null)
                    TextButton(onPressed: onDelete, child: Text(l10n.delete)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

String formatLogTime(BuildContext context, DateTime value) {
  return DateFormat.yMMMd(
    Localizations.localeOf(context).toLanguageTag(),
  ).add_Hm().format(value.toLocal());
}
