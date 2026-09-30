import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/providers.dart';
import '../../core/errors.dart';
import '../../data/repositories/items_repository.dart';
import '../common/common_widgets.dart';

enum AttachKind { gallery, camera, pdf }

Future<AttachKind?> chooseAttachKind(
  BuildContext context, {
  bool allowImages = true,
  bool allowPdf = true,
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
        const SizedBox(height: 8),
      ],
    ),
  ),
);

/// Picks a file and copies it into app storage. Returns null on cancel;
/// shows a snackbar (never throws) on errors.
Future<PickedAttachment?> pickAttachment(WidgetRef ref, AttachKind kind) async {
  final repo = ref.read(itemsRepositoryProvider);
  try {
    switch (kind) {
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
