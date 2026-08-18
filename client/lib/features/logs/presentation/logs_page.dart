import 'package:flutter/material.dart';
import 'package:momen_pair_client/features/auth/presentation/session_scope.dart';
import 'package:momen_pair_client/features/logs/domain/log_models.dart';
import 'package:momen_pair_client/features/logs/presentation/log_controller.dart';
import 'package:momen_pair_client/features/logs/presentation/log_detail_page.dart';
import 'package:momen_pair_client/features/logs/presentation/log_editor_page.dart';
import 'package:momen_pair_client/features/logs/presentation/log_scope.dart';
import 'package:momen_pair_client/features/logs/presentation/log_visuals.dart';
import 'package:momen_pair_client/l10n/generated/app_localizations.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = LogScope.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        controller.sync();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = LogScope.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LogBackdrop(
        child: RefreshIndicator(
          onRefresh: controller.load,
          child: CustomScrollView(
            key: const PageStorageKey('logs'),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context, controller)),
              ..._content(context, controller),
              const SliverPadding(padding: EdgeInsets.only(bottom: 36)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, LogController controller) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.logsTitle,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    l10n.logsDescription,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.62),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            _HeaderAction(
              tooltip: l10n.retry,
              icon: Icons.refresh_rounded,
              onPressed: controller.load,
            ),
            if (controller.status == LogsStatus.ready) ...[
              const SizedBox(width: 8),
              _HeaderAction(
                tooltip: l10n.createLog,
                icon: Icons.edit_outlined,
                emphasized: true,
                onPressed: controller.busy
                    ? null
                    : () => _openEditor(context, controller),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, LogController controller) {
    final l10n = AppLocalizations.of(context);
    return switch (controller.status) {
      LogsStatus.idle || LogsStatus.loading => const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      LogsStatus.noFamily => [
        _messageSliver(
          context,
          icon: Icons.family_restroom,
          title: l10n.familySpace,
          message: l10n.logsRequireFamily,
        ),
      ],
      LogsStatus.error => [
        _messageSliver(
          context,
          icon: Icons.cloud_off_outlined,
          title: l10n.logOperationFailed,
          message: _errorMessage(l10n, controller.errorCode),
          action: TextButton.icon(
            onPressed: controller.load,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.retry),
          ),
        ),
      ],
      LogsStatus.ready when controller.items.isEmpty => [
        _messageSliver(
          context,
          icon: Icons.auto_stories_outlined,
          title: l10n.logsEmptyTitle,
          message: l10n.logsEmptyDescription,
        ),
      ],
      LogsStatus.ready => [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
          sliver: SliverList.separated(
            itemCount: controller.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = controller.items[index];
              return _LogPanel(
                item: item,
                controller: controller,
                onTap: () => _openDetail(context, controller, item),
                onLike: () => controller.toggleLike(item),
              );
            },
          ),
        ),
        if (controller.hasMore)
          SliverToBoxAdapter(
            child: Center(
              child: TextButton(
                onPressed: controller.loadingMore ? null : controller.loadMore,
                child: controller.loadingMore
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.loadMore),
              ),
            ),
          ),
      ],
    };
  }

  SliverFillRemaining _messageSliver(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    final colors = Theme.of(context).colorScheme;
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: LogGlassSurface(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 34, color: colors.primary),
                  const SizedBox(height: 14),
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.66),
                    ),
                  ),
                  if (action != null) ...[const SizedBox(height: 14), action],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    LogController controller,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            LogScope(controller: controller, child: const LogEditorPage()),
      ),
    );
  }

  Future<void> _openDetail(
    BuildContext context,
    LogController controller,
    FamilyLog item,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LogScope(
          controller: controller,
          child: LogDetailPage(
            initialItem: item,
            currentUserId: SessionScope.of(context).session?.user.id,
          ),
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.emphasized = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: emphasized
                  ? colors.primary.withValues(alpha: 0.88)
                  : colors.surface.withValues(alpha: 0.58),
              border: Border.all(
                color: emphasized
                    ? colors.primary.withValues(alpha: 0.2)
                    : colors.outlineVariant.withValues(alpha: 0.42),
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child: SizedBox.square(
              dimension: 42,
              child: Icon(
                icon,
                size: 20,
                color: emphasized ? colors.onPrimary : colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogPanel extends StatelessWidget {
  const _LogPanel({
    required this.item,
    required this.controller,
    required this.onTap,
    required this.onLike,
  });

  final FamilyLog item;
  final LogController controller;
  final VoidCallback onTap;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return LogGlassSurface(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: colors.primaryContainer.withValues(
                  alpha: 0.68,
                ),
                foregroundColor: colors.onPrimaryContainer,
                child: Text(item.authorDisplayName.characters.first),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.authorDisplayName,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(
                      formatLogTime(context, item.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.58),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(item.title, style: Theme.of(context).textTheme.titleLarge),
          if (item.subtitle case final subtitle?) ...[
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant.withValues(alpha: 0.74),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            item.body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          if (item.media.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    LogRemoteImage(
                      media: item.media.first,
                      controller: controller,
                    ),
                    if (item.media.length > 1)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.58),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Text(
                              '+${item.media.length - 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 9),
          Row(
            children: [
              TextButton.icon(
                onPressed: onLike,
                icon: Icon(
                  item.likedByMe ? Icons.favorite : Icons.favorite_border,
                  size: 19,
                  color: item.likedByMe
                      ? colors.error
                      : colors.onSurfaceVariant,
                ),
                label: Text(l10n.likesCount(item.likeCount)),
              ),
              TextButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: Text(l10n.commentsCount(item.commentCount)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _errorMessage(AppLocalizations l10n, String? code) {
  return switch (code) {
    'log_version_conflict' => l10n.logVersionConflict,
    'family_required' => l10n.logsRequireFamily,
    _ => l10n.logOperationFailed,
  };
}
