const maxUrlLength = 2048;

final _urlInText = RegExp(
  r'''(?:https?://|www\.)[^\s<>"'`]+''',
  caseSensitive: false,
);

const _trailingPunctuation = '.,;:!?)]}\'"';

/// Returns the first http(s) or `www.` URL found in [text], normalised,
/// or null if there is none (or it is invalid).
String? extractFirstUrl(String text) {
  final match = firstUrlMatch(text);
  return match == null ? null : normalizeUrl(match.$1);
}

/// The first URL-looking substring of [text] and its start/end offsets.
(String, int, int)? firstUrlMatch(String text) {
  for (final m in _urlInText.allMatches(text)) {
    var candidate = m.group(0)!;
    while (candidate.isNotEmpty &&
        _trailingPunctuation.contains(candidate[candidate.length - 1])) {
      candidate = candidate.substring(0, candidate.length - 1);
    }
    if (normalizeUrl(candidate) != null) {
      return (candidate, m.start, m.start + candidate.length);
    }
  }
  return null;
}

/// Validates and normalises a URL typed by the user.
///
/// - `www.site.com` and bare `site.com/path` get `https://` prepended.
/// - Must be http or https with a host containing a dot (or `localhost`).
/// - Max [maxUrlLength] characters.
String? normalizeUrl(String input) {
  var value = input.trim();
  if (value.isEmpty || value.contains(RegExp(r'\s'))) return null;
  if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(value)) {
    value = 'https://$value';
  }
  if (value.length > maxUrlLength) return null;
  final uri = Uri.tryParse(value);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  final host = uri.host;
  if (host.isEmpty) return null;
  if (host != 'localhost' && !host.contains('.')) return null;
  if (host.startsWith('.') || host.endsWith('.')) return null;
  return value;
}

bool isValidUrl(String input) => normalizeUrl(input) != null;

/// Domain without a leading `www.`, e.g. `github.com`. Empty if unparsable.
String domainOf(String url) {
  final uri = Uri.tryParse(url);
  final host = uri?.host ?? '';
  return host.startsWith('www.') ? host.substring(4) : host;
}
