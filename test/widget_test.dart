import 'package:flutter_test/flutter_test.dart';
import 'package:snag/app/app.dart';
import 'package:snag/features/messenger/saved/saved_filter.dart';
import 'package:snag/data/local/app_database.dart';

SavedItem _item(
  String id, {
  String type = 'note',
  String title = 't',
  String? content,
  List<String> tags = const [],
  bool archived = false,
}) => SavedItem(
  id: id,
  ownerId: 'u',
  type: type,
  title: title,
  content: content,
  tags: tags,
  archived: archived,
  version: 1,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  testWidgets('shows "App not configured" without env values', (tester) async {
    await tester.pumpWidget(const NotConfiguredApp());
    expect(find.text('App not configured'), findsOneWidget);
  });

  test('saved filter: type, tag, archived and search', () {
    final items = [
      _item('1', title: 'Flutter docs', type: 'link', tags: ['dev']),
      _item('2', content: 'buy milk', tags: ['home']),
      _item('3', type: 'image', title: 'Image · Oct 3'),
      _item('4', content: 'old', archived: true),
    ];
    List<String> ids(SavedFilter f) =>
        applyFilter(items, f).map((e) => e.id).toList();

    expect(ids(const SavedFilter()), ['1', '2', '3']);
    expect(ids(const SavedFilter(type: TypeFilter.links)), ['1']);
    expect(ids(const SavedFilter(type: TypeFilter.images)), ['3']);
    expect(ids(const SavedFilter(tag: 'home')), ['2']);
    expect(ids(const SavedFilter(query: 'MILK')), ['2']);
    expect(ids(const SavedFilter(query: '#dev')), ['1']);
    expect(ids(const SavedFilter(archived: true)), ['4']);
    expect(allTags(items), ['dev', 'home']);
  });
}
