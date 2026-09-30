import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/date_utils.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/items_repository.dart';
import 'item_actions.dart';

/// Signed URL for a storage path (cached by the storage layer for 1 hour).
final signedUrlProvider = FutureProvider.family<String, String>(
  (ref, path) => ref.watch(itemsRepositoryProvider).signedUrl(path),
);

/// Shows an item's image: the local copy if present, else a signed URL.
class AttachmentImage extends ConsumerWidget {
  const AttachmentImage({
    super.key,
    required this.item,
    this.fit = BoxFit.cover,
    this.height,
  });
  final SavedItem item;
  final BoxFit fit;
  final double? height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    Widget placeholder(IconData icon) => Container(
      height: height ?? 160,
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(icon, color: scheme.onSurfaceVariant),
    );

    final local = item.localAttachmentPath;
    if (local != null && File(local).existsSync()) {
      return Image.file(
        File(local),
        fit: fit,
        height: height,
        width: double.infinity,
        cacheWidth: fit == BoxFit.cover ? 900 : null,
        errorBuilder: (_, _, _) => placeholder(Icons.broken_image_outlined),
      );
    }
    final path = item.remotePath;
    if (path == null) return placeholder(Icons.image_not_supported_outlined);

    return ref
        .watch(signedUrlProvider(path))
        .when(
          data: (url) => Image.network(
            url,
            fit: fit,
            height: height,
            width: double.infinity,
            loadingBuilder: (c, child, progress) => progress == null
                ? child
                : SizedBox(
                    height: height ?? 160,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
            errorBuilder: (_, _, _) => GestureDetector(
              onTap: () => ref.invalidate(signedUrlProvider(path)),
              child: placeholder(Icons.refresh),
            ),
          ),
          loading: () => SizedBox(
            height: height ?? 160,
            child: const Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => GestureDetector(
            onTap: () => ref.invalidate(signedUrlProvider(path)),
            child: placeholder(Icons.cloud_off_outlined),
          ),
        );
  }
}

/// File chip for PDF attachments: icon, name and (if known) size.
class PdfChip extends ConsumerWidget {
  const PdfChip({super.key, required this.item, this.dense = false});
  final SavedItem item;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final local = item.localAttachmentPath;
    String? size;
    if (local != null) {
      try {
        final f = File(local);
        if (f.existsSync()) size = formatBytes(f.lengthSync());
      } catch (_) {}
    }
    return Material(
      color: scheme.surface.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => openAttachment(ref, item),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.picture_as_pdf_rounded,
                  color: scheme.onErrorContainer,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachmentDisplayName(item),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      size == null ? 'PDF · tap to open' : 'PDF · $size',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FullScreenImage extends StatelessWidget {
  const FullScreenImage({super.key, required this.item});
  final SavedItem item;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          item.title,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: InteractiveViewer(
        maxScale: 5,
        child: Center(
          child: AttachmentImage(item: item, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

void openFullScreenImage(BuildContext context, SavedItem item) {
  Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute(builder: (_) => FullScreenImage(item: item)));
}
