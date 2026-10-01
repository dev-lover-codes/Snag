import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/url_utils.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/items_repository.dart';
import '../attachment_views.dart';
import '../item_actions.dart';

/// Notes that look like code use a monospace font.
bool looksLikeCode(String text) =>
    text.contains('{') || text.contains(';') || text.startsWith('    ');

class MessageBubble extends ConsumerWidget {
  const MessageBubble({super.key, required this.item});
  final SavedItem item;

  static const _clampLines = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final maxWidth = math.min(MediaQuery.sizeOf(context).width * 0.82, 560.0);
    final isImage = item.type == 'image';
    final isPdf = item.attachmentMime == pdfMime && item.remotePath != null;

    final children = <Widget>[];

    if (isImage) {
      children.add(
        GestureDetector(
          onTap: () => openFullScreenImage(context, item),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: AttachmentImage(item: item),
            ),
          ),
        ),
      );
      final autoTitle = item.title.startsWith('Image · ');
      if (!autoTitle || (item.content?.isNotEmpty ?? false)) {
        children.add(
          _padded(
            Text(
              (item.content?.isNotEmpty ?? false) ? item.content! : item.title,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }
    } else if (item.type == 'link') {
      children.add(
        _padded(
          InkWell(
            onTap: () => item.url == null ? null : openLink(item.url!),
            child: Container(
              padding: const EdgeInsets.only(left: 10),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: scheme.primary, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    domainOf(item.url ?? ''),
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      children.add(
        _padded(
          Text(
            item.url ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scheme.primary,
              decoration: TextDecoration.underline,
              decorationColor: scheme.primary.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
          top: 4,
        ),
      );
      if (item.content?.isNotEmpty ?? false) {
        children.add(_padded(_ClampedText(item.content!), top: 6));
      }
    } else {
      final text = item.content ?? '';
      if (text.isNotEmpty) {
        final firstLine = text.trimLeft().split('\n').first.trim();
        if (item.title.isNotEmpty &&
            item.title != firstLine &&
            !item.title.endsWith('…')) {
          children.add(
            _padded(
              Text(
                item.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          );
        }
        children.add(
          _padded(
            _ClampedText(
              text,
              maxLines: _clampLines,
              monospace: looksLikeCode(text),
              onShowMore: () => context.push('/item/${item.id}'),
            ),
            top: children.isEmpty ? 0 : 4,
          ),
        );
      } else if (!isPdf) {
        children.add(_padded(Text(item.title)));
      }
    }

    if (isPdf) {
      children.add(_padded(PdfChip(item: item), top: children.isEmpty ? 0 : 8));
    }

    if (item.tags.isNotEmpty) {
      children.add(
        _padded(
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final t in item.tags)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '#$t',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          top: 8,
        ),
      );
    }

    children.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (item.archived) ...[
              Icon(
                Icons.archive_outlined,
                size: 13,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
            ],
            if (item.updatedAt.difference(item.createdAt).inSeconds > 2) ...[
              Text(
                'edited ',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
            Text(
              formatTime(item.createdAt),
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 3),
            Icon(Icons.done_all_rounded, size: 14, color: scheme.primary),
          ],
        ),
      ),
    );

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, minWidth: 90),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(48, 3, 10, 3),
          child: Material(
            color: scheme.bubble,
            elevation: 0.5,
            shadowColor: Colors.black26,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(6),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push('/item/${item.id}'),
              onLongPress: () => showItemMenu(context, ref, item),
              child: Padding(
                padding: EdgeInsets.all(isImage ? 4 : 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isImage) const SizedBox(height: 8),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _padded(Widget child, {double top = 0}) =>
      Padding(padding: EdgeInsets.fromLTRB(12, top, 12, 0), child: child);
}

class _ClampedText extends StatelessWidget {
  const _ClampedText(
    this.text, {
    this.maxLines = 6,
    this.monospace = false,
    this.onShowMore,
  });
  final String text;
  final int maxLines;
  final bool monospace;
  final VoidCallback? onShowMore;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: monospace ? 13.5 : 15.5,
      height: 1.3,
      fontFamily: monospace ? 'monospace' : null,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Only measure long texts; short ones can't overflow.
        final long =
            text.length > 300 || '\n'.allMatches(text).length >= maxLines;
        var overflows = false;
        if (long) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            maxLines: maxLines,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: constraints.maxWidth);
          overflows = painter.didExceedMaxLines;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: style,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
            if (overflows && onShowMore != null)
              GestureDetector(
                onTap: onShowMore,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Show more',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class DateSeparator extends StatelessWidget {
  const DateSeparator({super.key, required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          daySeparatorLabel(date),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
