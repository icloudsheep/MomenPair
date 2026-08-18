import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:momen_pair_client/features/logs/domain/log_models.dart';
import 'package:momen_pair_client/features/logs/presentation/log_controller.dart';
import 'package:momen_pair_client/features/logs/presentation/log_scope.dart';
import 'package:momen_pair_client/features/logs/presentation/log_visuals.dart';
import 'package:momen_pair_client/l10n/generated/app_localizations.dart';

class LogEditorPage extends StatefulWidget {
  const LogEditorPage({this.item, super.key});

  final FamilyLog? item;

  @override
  State<LogEditorPage> createState() => _LogEditorPageState();
}

class _LogEditorPageState extends State<LogEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _body;
  late final List<_DraftImage> _images;
  bool _preview = false;
  bool _processingImages = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.item?.title);
    _subtitle = TextEditingController(text: widget.item?.subtitle);
    _body = TextEditingController(text: widget.item?.body);
    _images = [
      for (final media in widget.item?.media ?? const <LogMedia>[])
        _DraftImage.remote(media),
    ];
    unawaited(_recoverLostImages());
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(widget.item == null ? l10n.createLog : l10n.editLog),
        actions: [
          TextButton(
            onPressed: _saving || _processingImages ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.item == null ? l10n.publish : l10n.save),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LogBackdrop(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              _ModeSwitch(
                preview: _preview,
                onChanged: (value) => setState(() => _preview = value),
              ),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _preview
                    ? _buildPreview(context)
                    : _buildEditor(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditor(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final hintStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant.withValues(alpha: 0.58),
      fontSize: 12,
    );
    return Column(
      key: const ValueKey('editor'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LogGlassSurface(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Column(
            children: [
              TextFormField(
                controller: _title,
                maxLength: 100,
                textInputAction: TextInputAction.next,
                style: Theme.of(context).textTheme.titleLarge,
                decoration: _fieldDecoration(
                  l10n.logTitleLabel,
                  hintStyle,
                  counterStyle: hintStyle,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? l10n.logTitleRequired
                    : null,
              ),
              Divider(
                height: 1,
                color: colors.outlineVariant.withValues(alpha: 0.5),
              ),
              TextFormField(
                controller: _subtitle,
                maxLength: 200,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: _fieldDecoration(
                  l10n.logSubtitleLabel,
                  hintStyle,
                  counterStyle: hintStyle,
                ),
              ),
              Divider(
                height: 1,
                color: colors.outlineVariant.withValues(alpha: 0.5),
              ),
              TextFormField(
                controller: _body,
                minLines: 14,
                maxLines: null,
                maxLength: 50000,
                keyboardType: TextInputType.multiline,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(height: 1.6),
                decoration: _fieldDecoration(
                  l10n.logBodyHint,
                  hintStyle,
                  counterStyle: hintStyle,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? l10n.logBodyRequired
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildImagePicker(context),
        if (LogScope.of(context).errorCode != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage(l10n, LogScope.of(context).errorCode),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.error),
          ),
        ],
      ],
    );
  }

  Widget _buildPreview(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final title = _title.text.trim();
    final subtitle = _subtitle.text.trim();
    final body = _body.text.trim();
    return LogGlassSurface(
      key: const ValueKey('preview'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
          if (title.isNotEmpty || subtitle.isNotEmpty)
            const SizedBox(height: 18),
          if (body.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  l10n.previewEmpty,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.58),
                  ),
                ),
              ),
            )
          else
            LogMarkdownBody(data: body),
          if (_images.isNotEmpty) ...[
            const SizedBox(height: 16),
            _DraftGallery(images: _images, controller: LogScope.of(context)),
          ],
        ],
      ),
    );
  }

  Widget _buildImagePicker(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return LogGlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.addPhotos,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.photoLimitHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.58),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: l10n.addPhotos,
                onPressed: _images.length >= 9 || _processingImages
                    ? null
                    : _pickImages,
                icon: _processingImages
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_photo_alternate_outlined),
              ),
            ],
          ),
          if (_images.isNotEmpty) ...[
            const SizedBox(height: 12),
            _DraftGallery(
              images: _images,
              controller: LogScope.of(context),
              onRemove: (index) => setState(() => _images.removeAt(index)),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(
    String hint,
    TextStyle? hintStyle, {
    TextStyle? counterStyle,
  }) => InputDecoration(
    hintText: hint,
    hintStyle: hintStyle,
    counterStyle: counterStyle,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    contentPadding: const EdgeInsets.symmetric(vertical: 14),
  );

  Future<void> _pickImages() async {
    final files = await _picker.pickMultiImage(
      limit: 9 - _images.length,
      requestFullMetadata: false,
    );
    await _addFiles(files);
  }

  Future<void> _recoverLostImages() async {
    try {
      final response = await _picker.retrieveLostData();
      await _addFiles(response.files ?? const []);
    } on Object {
      return;
    }
  }

  Future<void> _addFiles(List<XFile> files) async {
    if (files.isEmpty || !mounted) {
      return;
    }
    setState(() => _processingImages = true);
    try {
      final remaining = 9 - _images.length;
      final additions = <_DraftImage>[];
      for (final file in files.take(remaining)) {
        final original = await file.readAsBytes();
        final compressed = await FlutterImageCompress.compressWithList(
          original,
          minWidth: 1920,
          minHeight: 1920,
          quality: 82,
          format: CompressFormat.webp,
        );
        additions.add(
          _DraftImage.local(
            compressed.isEmpty ? original : compressed,
            '${DateTime.now().microsecondsSinceEpoch}.webp',
          ),
        );
      }
      if (mounted) {
        setState(() => _images.addAll(additions));
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).imageUploadFailed),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingImages = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _preview = false);
      return;
    }
    setState(() => _saving = true);
    final controller = LogScope.of(context);
    final uploaded = <LogMedia>[];
    final mediaIds = <String>[];
    try {
      for (final image in _images) {
        if (image.media case final media?) {
          mediaIds.add(media.id);
          continue;
        }
        final media = await controller.uploadMedia(
          bytes: image.bytes!,
          filename: image.filename!,
        );
        if (media == null) {
          throw StateError('image_upload_failed');
        }
        uploaded.add(media);
        mediaIds.add(media.id);
      }
      final result = widget.item == null
          ? await controller.create(
              title: _title.text,
              subtitle: _subtitle.text,
              body: _body.text,
              mediaIds: mediaIds,
            )
          : await controller.update(
              widget.item!,
              title: _title.text,
              subtitle: _subtitle.text,
              body: _body.text,
              mediaIds: mediaIds,
            );
      if (result == null) {
        throw StateError('log_save_failed');
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on Object {
      for (final media in uploaded) {
        await controller.discardPendingMedia(media);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _errorMessage(AppLocalizations.of(context), controller.errorCode),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.preview, required this.onChanged});

  final bool preview;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.46),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ModeOption(
                label: l10n.editMode,
                selected: !preview,
                onTap: () => onChanged(false),
              ),
              _ModeOption(
                label: l10n.previewMode,
                selected: preview,
                onTap: () => onChanged(true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? colors.surface.withValues(alpha: 0.86)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.08),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected ? colors.onSurface : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _DraftGallery extends StatelessWidget {
  const _DraftGallery({
    required this.images,
    required this.controller,
    this.onRemove,
  });

  final List<_DraftImage> images;
  final LogController controller;
  final ValueChanged<int>? onRemove;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final image = images[index];
        final media = image.media;
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: media != null
                  ? LogRemoteImage(media: media, controller: controller)
                  : Image.memory(image.bytes!, fit: BoxFit.cover),
            ),
            if (onRemove != null)
              Positioned(
                right: 4,
                top: 4,
                child: IconButton.filled(
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  tooltip: AppLocalizations.of(context).removePhoto,
                  onPressed: () => onRemove!(index),
                  icon: const Icon(Icons.close),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DraftImage {
  const _DraftImage._({this.media, this.bytes, this.filename});

  factory _DraftImage.remote(LogMedia media) => _DraftImage._(media: media);
  factory _DraftImage.local(Uint8List bytes, String filename) =>
      _DraftImage._(bytes: bytes, filename: filename);

  final LogMedia? media;
  final Uint8List? bytes;
  final String? filename;
}

String _errorMessage(AppLocalizations l10n, String? code) {
  return switch (code) {
    'log_version_conflict' => l10n.logVersionConflict,
    'invalid_log_image' => l10n.imageUploadFailed,
    'family_required' => l10n.logsRequireFamily,
    _ => l10n.logOperationFailed,
  };
}
