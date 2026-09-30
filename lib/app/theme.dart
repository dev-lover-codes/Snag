import 'package:flutter/material.dart';

const snagTeal = Color(0xFF0F766E);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: snagTeal,
    brightness: brightness,
  );
  final isDark = brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 1,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      indicatorColor: scheme.primaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(
        alpha: isDark ? 0.5 : 0.6,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide(color: scheme.outlineVariant),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    ),
  );
}

/// Chat-specific colours derived from the scheme.
extension ChatColors on ColorScheme {
  /// Bubble for the user's own messages (Saved Messages are all "mine").
  Color get bubble => brightness == Brightness.dark
      ? Color.alphaBlend(primary.withValues(alpha: 0.28), surfaceContainer)
      : const Color(0xFFDDF3EE);
  Color get onBubble => onSurface;

  /// Subtle patterned chat background.
  Color get chatBackground => brightness == Brightness.dark
      ? const Color(0xFF0E1715)
      : const Color(0xFFEFF5F3);
}
