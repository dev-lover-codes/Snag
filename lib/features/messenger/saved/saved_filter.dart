import '../../../data/local/app_database.dart';

enum TypeFilter {
  all('All'),
  notes('Notes'),
  links('Links'),
  images('Images');

  const TypeFilter(this.label);
  final String label;
}

class SavedFilter {
  const SavedFilter({
    this.query = '',
    this.type = TypeFilter.all,
    this.tag,
    this.archived = false,
  });

  final String query;
  final TypeFilter type;
  final String? tag;

  /// Show the Archived list instead of the inbox.
  final bool archived;

  bool get isActive =>
      query.trim().isNotEmpty || type != TypeFilter.all || tag != null;

  SavedFilter copyWith({
    String? query,
    TypeFilter? type,
    String? Function()? tag,
    bool? archived,
  }) => SavedFilter(
    query: query ?? this.query,
    type: type ?? this.type,
    tag: tag != null ? tag() : this.tag,
    archived: archived ?? this.archived,
  );
}

/// Search matches title, content, URL and tags (case-insensitive).
List<SavedItem> applyFilter(List<SavedItem> items, SavedFilter f) {
  final q = f.query.trim().toLowerCase();
  final tagQuery = q.startsWith('#') ? q.substring(1) : q;
  return items.where((i) {
    if (i.archived != f.archived) return false;
    switch (f.type) {
      case TypeFilter.all:
        break;
      case TypeFilter.notes:
        if (i.type != 'note') return false;
      case TypeFilter.links:
        if (i.type != 'link') return false;
      case TypeFilter.images:
        if (i.type != 'image') return false;
    }
    if (f.tag != null && !i.tags.contains(f.tag)) return false;
    if (q.isEmpty) return true;
    return i.title.toLowerCase().contains(q) ||
        (i.content?.toLowerCase().contains(q) ?? false) ||
        (i.url?.toLowerCase().contains(q) ?? false) ||
        i.tags.any((t) => t.contains(tagQuery));
  }).toList();
}

/// Every tag the user has used, sorted.
List<String> allTags(List<SavedItem> items) =>
    ({for (final i in items) ...i.tags}.toList()..sort());
