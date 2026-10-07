import 'package:flutter/material.dart';

const green = Color(0xFF23634D);
const mint = Color(0xFFA9D6BD);
const coral = Color(0xFFD47C61);
const gold = Color(0xFFE1B85C);
const blue = Color(0xFF779AC0);
const chartColors = [
  green,
  coral,
  gold,
  blue,
  Color(0xFF9B89BB),
  Color(0xFF98B4A5),
];

ThemeData appTheme(bool dark) {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: green,
        brightness: dark ? Brightness.dark : Brightness.light,
      ).copyWith(
        primary: dark ? mint : green,
        surface: dark ? const Color(0xFF202823) : Colors.white,
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF141B17)
        : const Color(0xFFF6F7F2),
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.1,
        color: scheme.onSurface,
      ),
      headlineMedium: const TextStyle(
        fontSize: 25,
        fontWeight: FontWeight.w700,
        letterSpacing: -.7,
      ),
      titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      titleMedium: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      bodyMedium: const TextStyle(fontSize: 14, height: 1.5),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: dark ? const Color(0xFF303B33) : const Color(0xFFE6EAE2),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF28332B) : const Color(0xFFF4F6F1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: .5),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primary.withValues(alpha: .12),
    ),
    tooltipTheme: const TooltipThemeData(preferBelow: false),
  );
}
