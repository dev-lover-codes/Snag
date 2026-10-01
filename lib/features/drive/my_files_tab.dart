import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/errors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/remote/drive_remote.dart';
import '../common/common_widgets.dart';
import '../messenger/attachment_picker.dart';
import '../messenger/item_actions.dart';

/// Drive "My Files": the user's own private drive. Separate from chats.
class MyFilesTab extends ConsumerStatefulWidget {
  const MyFilesTab({super.key});

  @override
  ConsumerState<MyFilesTab> createState() => _MyFilesTabState();
}

class _MyFilesTabState extends ConsumerState<MyFilesTab> {
  bool _uploading = false;

  Future<void> _upload() async {
    final kind = await chooseAttachKind(context);
    if (kind == null || !mounted) return;
    final picked = await pickAttachment(ref, kind);
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      await ref.read(driveRepositoryProvider).upload(picked);
      ref.invalidate(driveFilesProvider);
      showSnack('Uploaded ${picked.name}');
    } catch (e) {
      showSnack(userMessageFor(e), actionLabel: 'Retry', onAction: _upload);
    } finally {
      try {
        File(picked.path).deleteSync();
      } catch (_) {}
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final files = ref.watch(driveFilesProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'drive-upload',
        tooltip: 'Upload',
        onPressed: _uploading ? null : _upload,
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          if (_uploading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(driveFilesProvider.future),
              child: files.when(
                loading: () => const LoadingView(),
                error: (e, _) => _scrollable(
                  ErrorView(
                    message: userMessageFor(e),
                    onRetry: () => ref.invalidate(driveFilesProvider),
                  ),
                ),
                data: (list) => _FileList(files: list),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lets pull-to-refresh work on centred, non-list content.
Widget _scrollable(Widget child) => LayoutBuilder(
  builder: (context, c) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [SizedBox(height: c.maxHeight, child: child)],
  ),
);

class _FileList extends StatelessWidget {
  const _FileList({required this.files});
  final List<DriveFile> files;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final used = files.fold<int>(0, (sum, f) => sum + f.sizeBytes);
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        'My Files · ${formatBytes(used)} used',
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
    if (files.isEmpty) {
      return LayoutBuilder(
        builder: (context, c) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            header,
            SizedBox(
              height: c.maxHeight - 48,
              child: const EmptyState(
                icon: Icons.cloud_upload_outlined,
                message: 'Your drive is empty — tap + to upload.',
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: files.length + 1,
      itemBuilder: (context, i) =>
          i == 0 ? header : _FileTile(file: files[i - 1]),
    );
  }
}

class _FileTile extends ConsumerWidget {
  const _FileTile({required this.file});
  final DriveFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: SizedBox(
        width: 48,
        height: 48,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: DriveThumbnail(file: file),
        ),
      ),
      title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${formatBytes(file.sizeBytes)} · ${formatShortDate(file.createdAt)}',
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'More',
        onSelected: (v) => v == 'rename'
            ? _rename(context, ref, file)
            : _delete(context, ref, file),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'rename', child: Text('Rename')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
      onTap: () => openDriveFile(context, ref, file),
    );
  }
}

/// Image thumbnail via a signed URL, or a PDF icon.
class DriveThumbnail extends ConsumerWidget {
  const DriveThumbnail({super.key, required this.file, this.fit});
  final DriveFile file;
  final BoxFit? fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    Widget icon(IconData i, {bool pdf = false}) => Container(
      color: pdf ? scheme.errorContainer : scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        i,
        color: pdf ? scheme.onErrorContainer : scheme.onSurfaceVariant,
      ),
    );
    if (file.isPdf) return icon(Icons.picture_as_pdf_rounded, pdf: true);
    return ref
        .watch(driveSignedUrlProvider(file))
        .when(
          data: (url) => Image.network(
            url,
            fit: fit ?? BoxFit.cover,
            cacheWidth: fit == null ? 200 : null,
            errorBuilder: (_, _, _) => icon(Icons.broken_image_outlined),
          ),
          loading: () => icon(Icons.image_outlined),
          error: (_, _) => icon(Icons.cloud_off_outlined),
        );
  }
}

Future<void> openDriveFile(
  BuildContext context,
  WidgetRef ref,
  DriveFile file,
) async {
  if (!file.isPdf) {
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (_) => _DriveImageViewer(file: file)));
    return;
  }
  try {
    await openLink(await ref.read(driveRepositoryProvider).signedUrl(file));
  } catch (e) {
    showSnack(userMessageFor(e));
  }
}

Future<void> _rename(BuildContext context, WidgetRef ref, DriveFile f) async {
  final controller = TextEditingController(text: f.name);
  final dot = f.name.lastIndexOf('.');
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: dot > 0 ? dot : f.name.length,
  );
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Rename file'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 200,
        decoration: const InputDecoration(labelText: 'Name'),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Rename'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (name == null || name.trim() == f.name) return;
  try {
    await ref.read(driveRepositoryProvider).rename(f, name);
    ref.invalidate(driveFilesProvider);
    showSnack('Renamed');
  } catch (e) {
    if (e is ItemGoneException) ref.invalidate(driveFilesProvider);
    showSnack(
      e is ItemGoneException
          ? 'This file no longer exists.'
          : userMessageFor(e),
    );
  }
}

Future<void> _delete(BuildContext context, WidgetRef ref, DriveFile f) async {
  final ok = await confirmDialog(
    context,
    title: 'Delete this file?',
    message: '“${f.name}” will be deleted from your drive on all devices.',
    confirmLabel: 'Delete',
    destructive: true,
  );
  if (!ok) return;
  try {
    await ref.read(driveRepositoryProvider).delete(f);
    ref.invalidate(driveFilesProvider);
    showSnack('Deleted');
  } catch (e) {
    showSnack(userMessageFor(e));
  }
}

class _DriveImageViewer extends StatelessWidget {
  const _DriveImageViewer({required this.file});
  final DriveFile file;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(file.name, overflow: TextOverflow.ellipsis)),
    body: InteractiveViewer(
      maxScale: 5,
      child: Center(
        child: DriveThumbnail(file: file, fit: BoxFit.contain),
      ),
    ),
  );
}
