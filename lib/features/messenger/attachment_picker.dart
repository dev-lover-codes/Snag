import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/providers.dart';
import '../../core/errors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/remote/drive_remote.dart';
import '../../data/repositories/items_repository.dart';
import '../drive/my_files_tab.dart' show DriveThumbnail;
import '../common/common_widgets.dart';

enum AttachKind { gallery, camera, pdf, drive }

Future<AttachKind?> chooseAttachKind(
  BuildContext context, {
  bool allowImages = true,
  bool allowPdf = true,
  bool allowDrive = false,
}) => showModalBottomSheet<AttachKind>(
  context: context,
  showDragHandle: true,
  builder: (ctx) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (allowImages) ...[
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Photo from gallery'),
            onTap: () => Navigator.pop(ctx, AttachKind.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(ctx, AttachKind.camera),
          ),
        ],
        if (allowPdf)
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('PDF document'),
            subtitle: const Text('Up to 10 MB'),
            onTap: () => Navigator.pop(ctx, AttachKind.pdf),
          ),
        if (allowDrive)
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: const Text('From My Drive'),
            subtitle: const Text('Send a copy of a file from Drive'),
            onTap: () => Navigator.pop(ctx, AttachKind.drive),
          ),
        const SizedBox(height: 8),
      ],
    ),
  ),
);

/// Picks a file and copies it into app storage. Returns null on cancel;
/// shows a snackbar (never throws) on errors.
Future<PickedAttachment?> pickAttachment(
  WidgetRef ref,
  AttachKind kind, {
  BuildContext? context,
  bool allowImages = true,
  bool allowPdf = true,
}) async {
  final repo = ref.read(itemsRepositoryProvider);
  try {
    switch (kind) {
      case AttachKind.drive:
        if (context == null || !context.mounted) return null;
        return await pickFromDrive(
          context,
          ref,
          allowImages: allowImages,
          allowPdf: allowPdf,
        );
      case AttachKind.gallery:
      case AttachKind.camera:
        final x = await ImagePicker().pickImage(
          source: kind == AttachKind.camera
              ? ImageSource.camera
              : ImageSource.gallery,
          maxWidth: 1600,
          imageQuality: 80,
        );
        if (x == null) return null;
        var name = x.name;
        if (mimeForPath(name) == null) {
          // Compressed output is JPEG even when the name says otherwise.
          name = '${p.basenameWithoutExtension(name)}.jpg';
        }
        if (kIsWeb) return _inMemory(await x.readAsBytes(), name, image: true);
        final staged = await repo.stagePickedFile(x.path, name: name);
        if (staged.isPdf) {
          throw const ValidationException('Pick an image file');
        }
        return staged;
      case AttachKind.pdf:
        final f = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: const ['pdf'],
        );
        if (f == null) return null;
        if (p.extension(f.name).toLowerCase() != '.pdf') {
          throw const ValidationException('Only PDF files can be attached');
        }
        if (kIsWeb) return _inMemory(await f.readAsBytes(), f.name);
        final size = f.lengthSync() ?? await f.length();
        if (size != null && size > maxAttachmentBytes) {
          throw const ValidationException(Messages.pdfTooLarge);
        }
        var path = f.path;
        if (path == null) {
          final tmp = await getTemporaryDirectory();
          path = p.join(
            tmp.path,
            'pick_${DateTime.now().microsecondsSinceEpoch}.pdf',
          );
          await File(path).writeAsBytes(await f.readAsBytes());
        }
        return await repo.stagePickedFile(path, name: f.name);
    }
  } catch (e) {
    showSnack(e is ValidationException ? e.message : "Couldn't open that file");
    return null;
  }
}

/// Website: browsers give bytes, not paths, so the file stays in memory.
PickedAttachment _inMemory(Uint8List bytes, String name, {bool image = false}) {
  final mime = mimeForPath(name);
  if (mime == null || (image && mime == pdfMime)) {
    throw ValidationException(
      image ? 'Pick an image file' : 'Only JPEG, PNG, WebP or PDF files',
    );
  }
  if (bytes.isEmpty) throw const ValidationException('That file is empty');
  if (bytes.length > maxAttachmentBytes) {
    throw ValidationException(
      mime == pdfMime ? Messages.pdfTooLarge : Messages.fileTooLarge,
    );
  }
  return PickedAttachment(
    path: 'web:$name',
    mime: mime,
    name: name,
    bytes: bytes,
  );
}

/// Lets the user choose a file from Drive → My Files and downloads a copy.
/// Returns null on cancel; errors surface as a snackbar from the caller.
Future<PickedAttachment?> pickFromDrive(
  BuildContext context,
  WidgetRef ref, {
  bool allowImages = true,
  bool allowPdf = true,
}) async {
  final file = await showModalBottomSheet<DriveFile>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) =>
        _DriveFileSheet(allowImages: allowImages, allowPdf: allowPdf),
  );
  if (file == null) return null;
  showSnack('Getting ${file.name}…');
  final picked = await ref.read(driveRepositoryProvider).asAttachment(file);
  scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
  return picked;
}

class _DriveFileSheet extends ConsumerWidget {
  const _DriveFileSheet({required this.allowImages, required this.allowPdf});
  final bool allowImages;
  final bool allowPdf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = ref.watch(driveFilesProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Choose from My Drive',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Flexible(
              child: files.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => ErrorView(
                  message: userMessageFor(e),
                  onRetry: () => ref.invalidate(driveFilesProvider),
                ),
                data: (all) {
                  final list = all
                      .where((f) => f.isPdf ? allowPdf : allowImages)
                      .toList();
                  if (list.isEmpty) {
                    return EmptyState(
                      icon: Icons.cloud_upload_outlined,
                      message: all.isEmpty
                          ? 'Your drive is empty. Upload files in Drive → My Files.'
                          : allowPdf
                          ? 'No PDFs in your drive.'
                          : 'No images in your drive.',
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final f = list[i];
                      return ListTile(
                        leading: SizedBox(
                          width: 44,
                          height: 44,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: DriveThumbnail(file: f),
                          ),
                        ),
                        title: Text(
                          f.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(formatBytes(f.sizeBytes)),
                        onTap: () => Navigator.pop(context, f),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
