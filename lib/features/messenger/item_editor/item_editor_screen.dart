import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../core/errors.dart';
import '../../../core/utils/share_parser.dart';
import '../../../core/utils/title_utils.dart';
import '../../../core/utils/url_utils.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/items_repository.dart';
import '../../common/common_widgets.dart';
import '../attachment_picker.dart';
import '../attachment_views.dart';
import '../item_actions.dart';
import '../saved/saved_screen.dart' show NewItemArgs;

enum EditorMode { create, edit, share }

/// Full create / edit screen (8.3). In [EditorMode.share] it is the share
/// confirm screen (8.5).
class ItemEditorScreen extends ConsumerStatefulWidget {
  const ItemEditorScreen.create({super.key, this.initialType, this.args})
    : mode = EditorMode.create,
      itemId = null,
      shareText = null;

  const ItemEditorScreen.edit({super.key, required String this.itemId})
    : mode = EditorMode.edit,
      initialType = null,
      args = null,
      shareText = null;

  const ItemEditorScreen.share({super.key, required String this.shareText})
    : mode = EditorMode.share,
      itemId = null,
      initialType = null,
      args = null;

  final EditorMode mode;
  final String? itemId;
  final String? initialType;
  final NewItemArgs? args;
  final String? shareText;

  @override
  ConsumerState<ItemEditorScreen> createState() => _ItemEditorScreenState();
}

class _ItemEditorScreenState extends ConsumerState<ItemEditorScreen> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _url = TextEditingController();

  String _type = 'note';
  List<String> _tags = [];
  PickedAttachment? _newAttachment;
  bool _removeAttachment = false;

  SavedItem? _original;
  bool _loading = true;
  bool _gone = false;
  bool _saving = false;
  String? _error;
  String _baseline = '';
  Timer? _debounce;
  late final String _newId = const Uuid().v4();

  String get _draftKey => switch (widget.mode) {
    EditorMode.create => 'new',
    EditorMode.share => 'share',
    EditorMode.edit => widget.itemId!,
  };

  @override
  void initState() {
    super.initState();
    for (final c in [_title, _content, _url]) {
      c.addListener(_onChanged);
    }
    _init();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    _content.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final repo = ref.read(itemsRepositoryProvider);
    ItemInput? base;

    switch (widget.mode) {
      case EditorMode.edit:
        try {
          final item = await repo.load(widget.itemId!);
          _original = item;
          base = ItemInput(
            type: item.type,
            title: item.title,
            content: item.content ?? '',
            url: item.url ?? '',
            tags: item.tags,
          );
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _gone = e is ItemGoneException;
            _error = e is ItemGoneException ? null : userMessageFor(e);
          });
          return;
        }
      case EditorMode.share:
        base = switch (parseSharedText(widget.shareText)) {
          SharedLink(:final url, :final title) => ItemInput(
            type: 'link',
            url: url,
            title: title ?? '',
          ),
          SharedNote(:final text) => ItemInput(type: 'note', content: text),
          ShareEmpty() => const ItemInput(),
        };
      case EditorMode.create:
        final args = widget.args;
        final hasArgs =
            args != null &&
            (args.text.trim().isNotEmpty || args.attachment != null);
        if (hasArgs) {
          final att = args.attachment;
          final url = extractFirstUrl(args.text);
          base = ItemInput(
            type: att != null
                ? (att.isPdf ? 'note' : 'image')
                : (url != null ? 'link' : 'note'),
            content: url != null && att == null ? '' : args.text,
            url: att == null ? (url ?? '') : '',
            newAttachment: att,
          );
          if (url != null && att == null) {
            final parsed = parseSharedText(args.text);
            if (parsed is SharedLink && parsed.title != null) {
              base = ItemInput(type: 'link', url: url, title: parsed.title!);
            }
          }
        } else {
          base = ItemInput(type: widget.initialType ?? 'note');
        }
    }

    _apply(base);
    _baseline = _currentInput().toDraft();

    // Restore unsaved changes (not for a fresh share or explicit prefill).
    final restoreDraft =
        widget.mode == EditorMode.edit ||
        (widget.mode == EditorMode.create &&
            (widget.args == null ||
                (widget.args!.text.trim().isEmpty &&
                    widget.args!.attachment == null)));
    if (restoreDraft) {
      final draft = await repo.loadDraft(_draftKey);
      if (draft != null && !draft.isBlank && mounted) {
        _apply(draft);
        showSnack(
          'Restored your unsaved changes',
          actionLabel: 'Discard',
          onAction: () {
            repo.deleteDraft(_draftKey);
            if (mounted) setState(() => _apply(base!));
          },
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _apply(ItemInput i) {
    _type = i.type;
    _title.text = i.title;
    _content.text = i.content;
    _url.text = i.url;
    _tags = [...i.tags];
    _newAttachment = i.newAttachment;
    _removeAttachment = i.removeAttachment;
  }

  ItemInput _currentInput() => ItemInput(
    type: _type,
    title: _title.text,
    content: _content.text,
    url: _url.text,
    tags: _tags,
    newAttachment: _newAttachment,
    removeAttachment: _removeAttachment,
  );

  bool get _dirty => !_loading && _currentInput().toDraft() != _baseline;

  void _onChanged() {
    if (_loading) return;
    if (_error != null) setState(() => _error = null);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _saveDraft);
  }

  void _setState(VoidCallback fn) {
    setState(fn);
    _onChanged();
  }

  Future<void> _saveDraft() async {
    if (!mounted || _loading) return;
    final repo = ref.read(itemsRepositoryProvider);
    if (_dirty) {
      await repo.saveDraft(_draftKey, _currentInput());
    } else {
      await repo.deleteDraft(_draftKey);
    }
  }

  bool get _hasExistingAttachment =>
      _original?.remotePath != null && !_removeAttachment;

  Future<void> _pick({required bool image}) async {
    AttachKind? kind = AttachKind.pdf;
    if (image) {
      kind = await chooseAttachKind(context, allowPdf: false);
    }
    if (kind == null) return;
    final picked = await pickAttachment(ref, kind);
    if (picked == null || !mounted) return;
    _setState(() => _newAttachment = picked);
  }

  void _removeCurrentAttachment() => _setState(() {
    _newAttachment = null;
    if (_original?.remotePath != null) _removeAttachment = true;
  });

  void _changeType(String type) => _setState(() {
    _type = type;
    // An image can't stay on a note/link, a PDF can't stay on an image.
    final att = _newAttachment;
    if (att != null && (type == 'image') == att.isPdf) _newAttachment = null;
    final existingMime = _original?.attachmentMime;
    if (existingMime != null &&
        (type == 'image') == (existingMime == pdfMime)) {
      _removeAttachment = true;
    }
  });

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final repo = ref.read(itemsRepositoryProvider);
    final input = _currentInput();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.mode == EditorMode.edit) {
        final ok = await runItemUpdate(
          context,
          ref,
          (v) => repo.update(_original!, input, baseVersion: v),
        );
        if (!ok) {
          if (mounted) setState(() => _saving = false);
          return;
        }
      } else {
        await repo.create(input, id: _newId);
      }
      _debounce?.cancel();
      await repo.deleteDraft(_draftKey);
      if (widget.mode == EditorMode.share) {
        await ref.read(pendingShareProvider.notifier).clear();
      }
      if (!mounted) return;
      _baseline = _currentInput().toDraft();
      showSnack(widget.mode == EditorMode.edit ? 'Saved' : 'Snagged!');
      if (widget.mode == EditorMode.share) {
        context.go('/messenger/saved');
      } else if (context.canPop()) {
        context.pop();
      } else {
        context.go('/messenger/saved');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = userMessageFor(e);
      });
    }
  }

  Future<void> _leave() async {
    if (_saving) return;
    if (widget.mode == EditorMode.share) {
      await ref.read(pendingShareProvider.notifier).clear();
      await ref.read(itemsRepositoryProvider).deleteDraft(_draftKey);
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/messenger');
      }
      return;
    }
    if (_dirty) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text('You can keep them as a draft and finish later.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'discard'),
              child: Text(
                'Discard',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'draft'),
              child: const Text('Keep draft'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep editing'),
            ),
          ],
        ),
      );
      if (choice == null || !mounted) return;
      _debounce?.cancel();
      final repo = ref.read(itemsRepositoryProvider);
      if (choice == 'discard') {
        await repo.deleteDraft(_draftKey);
      } else {
        await repo.saveDraft(_draftKey, _currentInput());
      }
    }
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/messenger/saved');
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.mode) {
      EditorMode.create => 'New item',
      EditorMode.edit => 'Edit item',
      EditorMode.share => 'Save to Snag',
    };

    if (_gone) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ItemGoneView(onBack: () => context.go('/messenger/saved')),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(
              widget.mode == EditorMode.share ? Icons.close : Icons.arrow_back,
            ),
            tooltip: widget.mode == EditorMode.share ? 'Cancel' : 'Back',
            onPressed: _leave,
          ),
          title: Text(title),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _loading || _saving ? null : _save,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
        body: _loading
            ? const LoadingView()
            : (_original == null && widget.mode == EditorMode.edit)
            ? ErrorView(
                message: _error ?? Messages.generic,
                onRetry: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _init();
                },
              )
            : _form(context),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final online = ref.watch(onlineProvider).value ?? true;
    return Column(
      children: [
        if (!online)
          MaterialBanner(
            content: const Text(Messages.offlineWrite),
            leading: const Icon(Icons.wifi_off_rounded),
            actions: const [SizedBox.shrink()],
          ),
        if (_saving) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'note',
                    label: Text('Note'),
                    icon: Icon(Icons.notes_rounded),
                  ),
                  ButtonSegment(
                    value: 'link',
                    label: Text('Link'),
                    icon: Icon(Icons.link_rounded),
                  ),
                  ButtonSegment(
                    value: 'image',
                    label: Text('Image'),
                    icon: Icon(Icons.image_outlined),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: _saving
                    ? null
                    : (s) => _changeType(s.first),
              ),
              const SizedBox(height: 16),
              if (_type == 'link') ...[
                TextField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  maxLength: maxUrlLength,
                  decoration: const InputDecoration(
                    labelText: 'Link',
                    hintText: 'https://…',
                    prefixIcon: Icon(Icons.link_rounded),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_type == 'image') ...[
                _imageSection(scheme),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _title,
                maxLength: maxTitleLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'Leave empty for an automatic title',
                  counterText: '',
                  helperText: _title.text.trim().isEmpty
                      ? 'Auto: ${_autoTitlePreview()}'
                      : null,
                  helperMaxLines: 1,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _content,
                minLines: _type == 'note' ? 6 : 2,
                maxLines: 14,
                maxLength: maxNoteLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: switch (_type) {
                    'note' => 'Note',
                    'image' => 'Caption (optional)',
                    _ => 'Note (optional)',
                  },
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              if (_type != 'image') ...[
                _pdfSection(scheme),
                const SizedBox(height: 16),
              ],
              Text('Tags', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TagInput(
                tags: _tags,
                suggestions: allTagsOf(ref),
                onChanged: (t) => _setState(() => _tags = t),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Card(
                  color: scheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: scheme.onErrorContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(color: scheme.onErrorContainer),
                          ),
                        ),
                        TextButton(
                          onPressed: _saving ? null : _save,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  widget.mode == EditorMode.share ? 'Save to Snag' : 'Save',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _autoTitlePreview() {
    final url = normalizeUrl(_url.text);
    return autoTitle(
      type: _type,
      content: _content.text,
      url: url,
      attachmentName: _newAttachment?.name,
    );
  }

  Widget _imageSection(ColorScheme scheme) {
    final att = _newAttachment;
    Widget? preview;
    if (att != null && !att.isPdf) {
      preview = Image.file(
        File(att.path),
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    } else if (_hasExistingAttachment && _original!.attachmentMime != pdfMime) {
      preview = AttachmentImage(item: _original!, height: 220);
    }
    if (preview == null) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(120),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: _saving ? null : () => _pick(image: true),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Pick an image'),
      );
    }
    return Stack(
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(14), child: preview),
        Positioned(
          right: 8,
          top: 8,
          child: Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'Replace image',
                onPressed: _saving ? null : () => _pick(image: true),
                icon: const Icon(Icons.swap_horiz_rounded),
              ),
              IconButton.filledTonal(
                tooltip: 'Remove image',
                onPressed: _saving ? null : _removeCurrentAttachment,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pdfSection(ColorScheme scheme) {
    final att = _newAttachment;
    String? name;
    if (att != null && att.isPdf) {
      name = att.name;
    } else if (_hasExistingAttachment && _original!.attachmentMime == pdfMime) {
      name = attachmentDisplayName(_original!);
    }
    if (name == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _saving ? null : () => _pick(image: false),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Attach PDF'),
        ),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(Icons.picture_as_pdf_rounded, color: scheme.error),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(att != null ? 'New attachment' : 'Attached'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Replace PDF',
              icon: const Icon(Icons.swap_horiz_rounded),
              onPressed: _saving ? null : () => _pick(image: false),
            ),
            IconButton(
              tooltip: 'Remove PDF',
              icon: const Icon(Icons.close),
              onPressed: _saving ? null : _removeCurrentAttachment,
            ),
          ],
        ),
      ),
    );
  }
}
