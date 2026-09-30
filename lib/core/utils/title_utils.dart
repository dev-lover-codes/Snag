import 'date_utils.dart';
import 'url_utils.dart';

const maxTitleLength = 200;
const autoTitleNoteLength = 60;

/// Auto-title rules from section 9:
/// link → domain without `www.`; note → first line (max 60 chars + `…`);
/// image → `Image · Oct 3, 14:05`.
String autoTitle({
  required String type,
  String? content,
  String? url,
  String? attachmentName,
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  switch (type) {
    case 'link':
      final domain = url == null ? '' : domainOf(url);
      return domain.isEmpty ? 'Link' : domain;
    case 'image':
      return 'Image · ${formatDateTime(at, now: at)}';
    default:
      final firstLine = (content ?? '')
          .split('\n')
          .map((l) => l.trim())
          .firstWhere((l) => l.isNotEmpty, orElse: () => '');
      if (firstLine.isEmpty) {
        if (attachmentName != null && attachmentName.isNotEmpty) {
          return clampTitle(attachmentName);
        }
        return 'Note';
      }
      if (firstLine.runes.length <= autoTitleNoteLength) return firstLine;
      return '${_takeRunes(firstLine, autoTitleNoteLength).trimRight()}…';
  }
}

/// Trims the user's title; falls back to [autoTitle] when empty.
String resolveTitle(
  String? input, {
  required String type,
  String? content,
  String? url,
  String? attachmentName,
  DateTime? now,
}) {
  final trimmed = (input ?? '').trim();
  if (trimmed.isNotEmpty) return clampTitle(trimmed);
  return autoTitle(
    type: type,
    content: content,
    url: url,
    attachmentName: attachmentName,
    now: now,
  );
}

String clampTitle(String title) => title.runes.length <= maxTitleLength
    ? title
    : _takeRunes(title, maxTitleLength);

/// Cuts by Unicode code points so emoji are never split in half.
String _takeRunes(String s, int n) => String.fromCharCodes(s.runes.take(n));
