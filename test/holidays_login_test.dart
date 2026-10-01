import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snag/core/utils/validators.dart';
import 'package:snag/data/remote/holidays_remote.dart';
import 'package:snag/features/calendar/month_view.dart';

void main() {
  group('Sign-in field accepts email or username', () {
    test('valid', () {
      expect(validateLoginId('raaj@example.com'), isNull);
      expect(validateLoginId('  raaj_01 '), isNull);
      expect(validateLoginId('@Raaj_01'), isNull);
    });
    test('invalid', () {
      expect(validateLoginId(''), 'Enter your email or username');
      expect(validateLoginId('ab'), 'Enter a valid email or username');
      expect(validateLoginId('raaj@'), 'Enter a valid email address');
      expect(validateLoginId('two words'), 'Enter a valid email or username');
    });
  });

  group('Holidays', () {
    test('rows become local days', () {
      final h = Holiday.fromRow({
        'date': '2026-11-08',
        'name': 'Diwali/Deepavali',
        'type': 'public',
      });
      expect(h.date, DateTime(2026, 11, 8));
      expect(h.isPublic, isTrue);
      expect(
        Holiday.fromRow({
          'date': '2026-11-11',
          'name': 'Bhai Duj',
          'type': 'observance',
        }).isPublic,
        isFalse,
      );
    });

    test('prefs survive a round trip and reject unknown regions', () {
      const p = HolidayPrefs(region: 'us', observances: false);
      final back = HolidayPrefs.fromJson(p.toJson());
      expect(back.region, 'us');
      expect(back.observances, isFalse);
      expect(HolidayPrefs.fromJson('{"region":"xx"}').region, isNull);
      expect(HolidayPrefs.fromJson('not json').region, 'in');
      expect(HolidayPrefs.fromJson(null).region, 'in');
    });

    testWidgets('month grid labels holiday days', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MonthView(
              month: DateTime(2026, 11),
              selected: DateTime(2026, 11, 1),
              eventCounts: const {},
              holidays: {
                DateTime(2026, 11, 8): [
                  Holiday(
                    date: DateTime(2026, 11, 8),
                    name: 'Diwali/Deepavali',
                    isPublic: true,
                  ),
                ],
              },
              onSelect: (_) {},
              onMonthChanged: (_) {},
            ),
          ),
        ),
      );
      expect(
        find.bySemanticsLabel(RegExp('Nov 8, Diwali/Deepavali')),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });
}
