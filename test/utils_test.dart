import 'package:flutter_test/flutter_test.dart';
import 'package:snag/core/utils/date_utils.dart';
import 'package:snag/core/utils/share_parser.dart';
import 'package:snag/core/utils/tag_utils.dart';
import 'package:snag/core/utils/title_utils.dart';
import 'package:snag/core/utils/url_utils.dart';
import 'package:snag/core/utils/validators.dart';

void main() {
  group('url_utils', () {
    test('normalizeUrl accepts http(s) and prepends https to www', () {
      expect(normalizeUrl('https://github.com/a'), 'https://github.com/a');
      expect(normalizeUrl('http://x.io'), 'http://x.io');
      expect(normalizeUrl('www.site.com'), 'https://www.site.com');
      expect(
        normalizeUrl('  github.com/flutter  '),
        'https://github.com/flutter',
      );
    });

    test('normalizeUrl rejects invalid input', () {
      for (final bad in [
        '',
        '   ',
        'not a url',
        'ftp://x.com',
        'javascript:alert(1)',
        'https://',
        'hello',
        'https://${'a' * 2100}.com',
      ]) {
        expect(normalizeUrl(bad), isNull, reason: bad);
      }
    });

    test('extractFirstUrl finds the first URL and trims punctuation', () {
      expect(
        extractFirstUrl('look at https://youtu.be/abc, cool!'),
        'https://youtu.be/abc',
      );
      expect(extractFirstUrl('see www.x.com.'), 'https://www.x.com');
      expect(extractFirstUrl('(https://a.com/b)'), 'https://a.com/b');
      expect(extractFirstUrl('no links here e.g. this'), isNull);
    });

    test('domainOf strips www', () {
      expect(domainOf('https://www.github.com/x'), 'github.com');
      expect(domainOf('https://m.youtube.com'), 'm.youtube.com');
      expect(domainOf('garbage'), '');
    });
  });

  group('title_utils', () {
    final now = DateTime(2026, 10, 3, 14, 5);

    test('link → domain', () {
      expect(
        autoTitle(type: 'link', url: 'https://www.github.com/x'),
        'github.com',
      );
    });

    test('note → first non-empty line, max 60 chars + …', () {
      expect(autoTitle(type: 'note', content: '\n  hello\nworld'), 'hello');
      final long = 'a' * 80;
      final t = autoTitle(type: 'note', content: long);
      expect(t, '${'a' * 60}…');
    });

    test('image → Image · Oct 3, 14:05', () {
      expect(autoTitle(type: 'image', now: now), 'Image · Oct 3, 14:05');
    });

    test('emoji are not split', () {
      final emoji = '😀' * 70;
      final t = autoTitle(type: 'note', content: emoji);
      expect(t, '${'😀' * 60}…');
    });

    test('resolveTitle trims and clamps to 200', () {
      expect(resolveTitle('  hi  ', type: 'note'), 'hi');
      expect(resolveTitle('x' * 300, type: 'note').length, 200);
      expect(resolveTitle('   ', type: 'note', content: 'body'), 'body');
    });
  });

  group('tag_utils', () {
    test('normalizeTag', () {
      expect(normalizeTag('  #DSA '), 'dsa');
      expect(normalizeTag('##Placement'), 'placement');
      expect(normalizeTag('my tag'), 'my-tag');
      expect(normalizeTag('c++'), 'c');
      expect(normalizeTag('   '), isNull);
      expect(normalizeTag('#'), isNull);
      expect(normalizeTag('a' * 31), isNull);
      expect(normalizeTag('🔥'), isNull);
    });

    test('normalizeTags dedupes and caps at 10', () {
      expect(normalizeTags(['A', 'a', '#a', 'b']), ['a', 'b']);
      expect(normalizeTags(List.generate(15, (i) => 't$i')).length, 10);
    });

    test('parseTagInput splits on commas and spaces', () {
      expect(parseTagInput('#dsa, placement notes'), [
        'dsa',
        'placement',
        'notes',
      ]);
    });
  });

  group('share parser', () {
    test('URL only → link with auto title', () {
      final r = parseSharedText('https://youtu.be/dQw4w9WgXcQ');
      expect(r, isA<SharedLink>());
      r as SharedLink;
      expect(r.url, 'https://youtu.be/dQw4w9WgXcQ');
      expect(r.title, isNull);
    });

    test('text + URL → link titled with the text', () {
      final r =
          parseSharedText('Great talk on Flutter - https://youtu.be/x')
              as SharedLink;
      expect(r.url, 'https://youtu.be/x');
      expect(r.title, 'Great talk on Flutter');
    });

    test('plain text → note', () {
      final r = parseSharedText('  remember the milk ');
      expect(r, isA<SharedNote>());
      expect((r as SharedNote).text, 'remember the milk');
    });

    test('empty / whitespace / null → empty', () {
      expect(parseSharedText(null), isA<ShareEmpty>());
      expect(parseSharedText(''), isA<ShareEmpty>());
      expect(parseSharedText('  \n\t '), isA<ShareEmpty>());
    });

    test('very long text is clamped, emoji-only works', () {
      final r = parseSharedText('x' * 30000) as SharedNote;
      expect(r.text.length, maxNoteLength);
      expect(parseSharedText('🔥🔥🔥'), isA<SharedNote>());
    });

    test('URL with only separators left has no title', () {
      final r = parseSharedText('— https://a.com —') as SharedLink;
      expect(r.title, isNull);
    });
  });

  group('validators', () {
    test('username', () {
      expect(validateUsername('ayaz_01'), isNull);
      expect(validateUsername('AB'), isNotNull);
      expect(validateUsername('has space'), isNotNull);
      expect(validateUsername('a' * 21), isNotNull);
    });
    test('email + password', () {
      expect(validateEmail('a@b.co'), isNull);
      expect(validateEmail('nope'), isNotNull);
      expect(validatePassword('1234567'), isNotNull);
      expect(validatePassword('12345678'), isNull);
    });
  });

  group('date_utils', () {
    final now = DateTime(2026, 10, 3, 12);
    test('day separators', () {
      expect(daySeparatorLabel(DateTime(2026, 10, 3, 1), now: now), 'Today');
      expect(
        daySeparatorLabel(DateTime(2026, 10, 2, 23), now: now),
        'Yesterday',
      );
      expect(daySeparatorLabel(DateTime(2026, 9, 28), now: now), 'Sep 28');
      expect(
        daySeparatorLabel(DateTime(2025, 9, 28), now: now),
        'Sep 28, 2025',
      );
    });
    test('formatBytes', () {
      expect(formatBytes(500), '500 B');
      expect(formatBytes(2048), '2 KB');
      expect(formatBytes(3 * 1024 * 1024), '3.0 MB');
    });
  });
}
