import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snag/features/calendar/month_view.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required DateTime month,
    Map<DateTime, int> counts = const {},
    ValueChanged<DateTime>? onSelect,
    ValueChanged<DateTime>? onMonth,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MonthView(
          month: month,
          selected: DateTime(2026, 10, 1),
          eventCounts: counts,
          onSelect: onSelect ?? (_) {},
          onMonthChanged: onMonth ?? (_) {},
        ),
      ),
    ),
  );

  testWidgets('October 2026 starts on Thursday in a Monday-first grid', (
    tester,
  ) async {
    await pump(tester, month: DateTime(2026, 10));
    expect(find.text('October 2026'), findsOneWidget);
    // Sep 28–30 lead in; 31 days → 5 rows ending on Sunday Nov 1.
    expect(find.text('28'), findsNWidgets(2)); // Sep 28 and Oct 28
    expect(find.text('31'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(2)); // Oct 1 and Nov 1
  });

  testWidgets('tapping a day selects it; arrows change month', (tester) async {
    DateTime? picked;
    DateTime? month;
    await pump(
      tester,
      month: DateTime(2026, 10),
      onSelect: (d) => picked = d,
      onMonth: (m) => month = m,
    );
    await tester.tap(find.text('15'));
    expect(picked, DateTime(2026, 10, 15));
    await tester.tap(find.byTooltip('Next month'));
    expect(month, DateTime(2026, 11));
    await tester.tap(find.byTooltip('Previous month'));
    expect(month, DateTime(2026, 9));
  });

  testWidgets('days with events are labelled with their count', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(
      tester,
      month: DateTime(2026, 10),
      counts: {DateTime(2026, 10, 15): 5, DateTime(2026, 10, 20): 1},
    );
    expect(find.bySemanticsLabel(RegExp('Oct 15, 5 events')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Oct 20, 1 event')), findsOneWidget);
    semantics.dispose();
  });
}
