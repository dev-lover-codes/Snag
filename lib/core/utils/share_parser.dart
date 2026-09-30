import 'title_utils.dart';
import 'url_utils.dart';

const maxNoteLength = 20000;

/// What a piece of shared text turns into.
sealed class ShareParseResult {
  const ShareParseResult();
}

class SharedLink extends ShareParseResult {
  const SharedLink({required this.url, this.title});
  final String url;

  /// The rest of the shared text, if it is meaningful; else null (auto-title).
  final String? title;
}

class SharedNote extends ShareParseResult {
  const SharedNote(this.text);
  final String text;
}

class ShareEmpty extends ShareParseResult {
  const ShareEmpty();
}

final _meaningful = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// Rules from Stage 3: first http(s) URL → link (title = remaining text if
/// meaningful); no URL → note; empty/whitespace → [ShareEmpty].
/// Never throws.
ShareParseResult parseSharedText(String? text) {
  try {
    if (text == null) return const ShareEmpty();
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const ShareEmpty();

    final match = firstUrlMatch(trimmed);
    if (match != null) {
      final url = normalizeUrl(match.$1)!;
      var rest =
          '${trimmed.substring(0, match.$2)} ${trimmed.substring(match.$3)}'
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
      // Strip separators apps put between the title and the link.
      rest = rest
          .replaceAll(RegExp(r'^[\s\-–—|:•]+'), '')
          .replaceAll(RegExp(r'[\s\-–—|:•]+$'), '')
          .trim();
      final title = rest.length >= 2 && _meaningful.hasMatch(rest)
          ? clampTitle(rest)
          : null;
      return SharedLink(url: url, title: title);
    }

    final note = trimmed.runes.length > maxNoteLength
        ? String.fromCharCodes(trimmed.runes.take(maxNoteLength))
        : trimmed;
    return SharedNote(note);
  } catch (_) {
    return const ShareEmpty();
  }
}
