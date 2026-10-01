import 'package:flutter/material.dart';

import '../../core/utils/date_utils.dart';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// A month grid (weeks start on Monday): today is outlined, the selected
/// day is filled, and days with events get up to three dots.
/// Swipe left/right or use the arrows to change month.
class MonthView extends StatelessWidget {
  const MonthView({
    super.key,
    required this.month,
    required this.selected,
    required this.eventCounts,
    required this.onSelect,
    required this.onMonthChanged,
  });

  /// Any date in the month to show (only year and month are used).
  final DateTime month;
  final DateTime selected;

  /// Number of events per local day (keys from [startOfDay]).
  final Map<DateTime, int> eventCounts;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<DateTime> onMonthChanged;

  void _shift(int months) =>
      onMonthChanged(DateTime(month.year, month.month + months));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final first = DateTime(month.year, month.month);
    // Monday-first grid: back up to the Monday on or before the 1st.
    final gridStart = first.subtract(Duration(days: first.weekday - 1));
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((first.weekday - 1 + daysInMonth) / 7).ceil();
    final today = startOfDay(DateTime.now());

    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() < 200) return;
        _shift(v < 0 ? 1 : -1);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_monthNames[month.month - 1]} ${month.year}',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Previous month',
                onPressed: () => _shift(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: () => _shift(1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final w in _weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var r = 0; r < rows; r++)
            Row(
              children: List.generate(7, (c) {
                final day = DateTime(
                  gridStart.year,
                  gridStart.month,
                  gridStart.day + r * 7 + c,
                );
                return Expanded(
                  child: _DayCell(
                    day: day,
                    inMonth: day.month == month.month,
                    today: today,
                    selected: selected,
                    count: eventCounts[day] ?? 0,
                    onTap: onSelect,
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.today,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final DateTime today;
  final DateTime selected;
  final int count;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = day == selected;
    final isToday = day == today;
    final fg = isSelected
        ? scheme.onPrimary
        : !inMonth
        ? scheme.onSurfaceVariant.withValues(alpha: 0.5)
        : isToday
        ? scheme.primary
        : scheme.onSurface;

    return Semantics(
      button: true,
      selected: isSelected,
      label:
          '${formatShortDate(day)}${count > 0 ? ', $count event${count == 1 ? '' : 's'}' : ''}',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => onTap(day),
        child: SizedBox(
          height: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? scheme.primary : null,
                  border: isToday && !isSelected
                      ? Border.all(color: scheme.primary, width: 1.5)
                      : null,
                ),
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    color: fg,
                    fontWeight: isToday || isSelected
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: 5,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < count.clamp(0, 3); i++)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: inMonth
                              ? scheme.tertiary
                              : scheme.tertiary.withValues(alpha: 0.4),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
