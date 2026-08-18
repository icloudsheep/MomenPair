import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:momen_pair_client/features/logs/domain/log_models.dart';
import 'package:momen_pair_client/features/logs/presentation/log_controller.dart';

class LogBackdrop extends StatelessWidget {
  const LogBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryContainer.withValues(alpha: 0.26),
            colors.surface,
            colors.tertiaryContainer.withValues(alpha: 0.16),
          ],
          stops: const [0, 0.48, 1],
        ),
      ),
      child: child,
    );
  }
}

class LogGlassSurface extends StatelessWidget {
  const LogGlassSurface({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.radius = 14,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = Padding(padding: padding, child: child);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.62),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.42),
            ),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: onTap == null
              ? content
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  child: content,
                ),
        ),
      ),
    );
  }
}

class LogMarkdownBody extends StatelessWidget {
  const LogMarkdownBody({required this.data, super.key});

  final String data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    return MarkdownBody(
      data: data,
      selectable: true,
      softLineBreak: true,
      styleSheet: MarkdownStyleSheet(
        p: textTheme.bodyLarge?.copyWith(height: 1.62),
        pPadding: const EdgeInsets.only(bottom: 10),
        h1: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        h1Padding: const EdgeInsets.only(top: 12, bottom: 10),
        h2: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        h2Padding: const EdgeInsets.only(top: 12, bottom: 8),
        h3: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        h3Padding: const EdgeInsets.only(top: 10, bottom: 6),
        blockquoteDecoration: BoxDecoration(
          color: colors.primaryContainer.withValues(alpha: 0.28),
          border: Border(left: BorderSide(color: colors.primary, width: 3)),
        ),
        blockquotePadding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        code: textTheme.bodyMedium?.copyWith(
          fontFamily: 'monospace',
          backgroundColor: Colors.transparent,
        ),
        codeblockDecoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        listIndent: 22,
        horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
      ),
    );
  }
}

class LogRemoteImage extends StatelessWidget {
  const LogRemoteImage({
    required this.media,
    required this.controller,
    this.fit = BoxFit.cover,
    super.key,
  });

  final LogMedia media;
  final LogController controller;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      controller.mediaUri(media).toString(),
      headers: controller.mediaHeaders,
      fit: fit,
      errorBuilder: (_, __, ___) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}

class LogMediaGallery extends StatelessWidget {
  const LogMediaGallery({
    required this.media,
    required this.controller,
    super.key,
  });

  final List<LogMedia> media;
  final LogController controller;

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) {
      return const SizedBox.shrink();
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: media.length == 1 ? 1 : 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: media.length == 1 ? 16 / 10 : 1,
      ),
      itemCount: media.length,
      itemBuilder: (context, index) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LogRemoteImage(media: media[index], controller: controller),
      ),
    );
  }
}
