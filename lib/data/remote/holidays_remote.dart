import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

/// A row of `public.holidays` (read-only, same for everyone).
class Holiday {
  const Holiday({
    required this.date,
    required this.name,
    required this.isPublic,
  });

  /// Local calendar day (no time).
  final DateTime date;
  final String name;

  /// Public holiday; otherwise a festival or observance.
  final bool isPublic;

  factory Holiday.fromRow(Map<String, dynamic> row) {
    final d = DateTime.parse(row['date'] as String);
    return Holiday(
      date: DateTime(d.year, d.month, d.day),
      name: row['name'] as String,
      isPublic: row['type'] == 'public',
    );
  }
}

/// Holiday calendars the Calendar tab can show (code → display name).
const holidayRegions = <String, String>{
  'in': 'India',
  'us': 'United States',
  'uk': 'United Kingdom',
  'ca': 'Canada',
  'au': 'Australia',
  'ae': 'United Arab Emirates',
  'sg': 'Singapore',
  'de': 'Germany',
  'fr': 'France',
  'jp': 'Japan',
};

/// Which holidays to show; stored on this device only.
class HolidayPrefs {
  const HolidayPrefs({this.region = 'in', this.observances = true});

  /// A code from [holidayRegions], or null to hide holidays.
  final String? region;

  /// Also show festivals and observances, not just public holidays.
  final bool observances;

  HolidayPrefs copyWith({String? Function()? region, bool? observances}) =>
      HolidayPrefs(
        region: region == null ? this.region : region(),
        observances: observances ?? this.observances,
      );

  String toJson() => jsonEncode({'region': region, 'observances': observances});

  static HolidayPrefs fromJson(String? raw) {
    if (raw == null) return const HolidayPrefs();
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final r = m['region'];
      return HolidayPrefs(
        region: r is String && holidayRegions.containsKey(r) ? r : null,
        observances: m['observances'] != false,
      );
    } catch (_) {
      return const HolidayPrefs();
    }
  }
}

class HolidaysRemote {
  HolidaysRemote(this._client);
  final SupabaseClient _client;

  /// All holidays for [region], oldest first.
  Future<List<Holiday>> fetch(String region) async {
    final rows = await _client
        .from('holidays')
        .select('date, name, type')
        .eq('region', region)
        .order('date', ascending: true)
        .timeout(const Duration(seconds: 20));
    return rows.map(Holiday.fromRow).toList();
  }
}
