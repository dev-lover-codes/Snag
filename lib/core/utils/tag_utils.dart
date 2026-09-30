const maxTagsPerItem = 10;
const maxTagLength = 30;

/// Suggested tags shown in the editor (plus the user's existing tags).
const defaultTagSuggestions = ['dsa', 'placement', 'project', 'notes'];

final _invalidTagChars = RegExp(r'[^a-z0-9_-]');

/// Normalises one tag: trim, strip leading `#`, lowercase, spaces → `-`,
/// drop characters outside `[a-z0-9_-]`. Returns null if the result is not
/// 1–30 characters long.
String? normalizeTag(String raw) {
  var tag = raw.trim();
  while (tag.startsWith('#')) {
    tag = tag.substring(1);
  }
  tag = tag
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(_invalidTagChars, '');
  if (tag.isEmpty || tag.length > maxTagLength) return null;
  return tag;
}

/// Normalises, deduplicates (keeping order) and caps at [maxTagsPerItem].
List<String> normalizeTags(Iterable<String> raw) {
  final seen = <String>{};
  for (final r in raw) {
    final t = normalizeTag(r);
    if (t != null) seen.add(t);
    if (seen.length == maxTagsPerItem) break;
  }
  return seen.toList();
}

/// Splits free text like `#dsa, placement notes` into normalised tags.
List<String> parseTagInput(String input) =>
    normalizeTags(input.split(RegExp(r'[,\s]+')));
