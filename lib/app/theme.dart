import 'package:flutter/material.dart';

abstract final class AppColors {
  static const bg = Color(0xFFF4EEFF);
  static const bgDeep = Color(0xFFE6DCFF);
  static const surface = Colors.white;
  static const ink = Color(0xFF2A2150);
  static const inkSoft = Color(0xFF6E6699);
  static const primary = Color(0xFF6B4EFF);
  static const primaryDark = Color(0xFF4B32D6);
  static const accent = Color(0xFFFF8A3D);
  static const success = Color(0xFF2ECC8F);
  static const danger = Color(0xFFFF5470);
  static const coin = Color(0xFFFFC233);
  static const gem = Color(0xFF29C5F6);
  static const star = Color(0xFFFFB800);
  static const boardBg = Color(0xFF3A2F73);
  static const boardCell = Color(0xFF4A3E8A);

  /// Classic shape palette (index = ShapeColor.*).
  static const blocks = [
    Color(0xFFFF5A6E), // red
    Color(0xFFFF9F43), // orange
    Color(0xFFFFD23F), // yellow
    Color(0xFF3DD68C), // green
    Color(0xFF22C7C7), // teal
    Color(0xFF4D8BFF), // blue
    Color(0xFF9B5CFF), // purple
    Color(0xFFFF6FB5), // pink
  ];

  /// Adventure colour names.
  static const named = {
    'red': Color(0xFFFF5A6E),
    'blue': Color(0xFF4D8BFF),
    'green': Color(0xFF3DD68C),
    'yellow': Color(0xFFFFC93F),
    'purple': Color(0xFF9B5CFF),
  };
  static const crate = Color(0xFFB98A5E);
  static const stone = Color(0xFF8A8FA8);
  static const ice = Color(0xFFBDEBFF);

  static Color blockColor(int index) => index < 0 ? Colors.white : blocks[index % blocks.length];
  static Color named_(String? name) => named[name] ?? crate;
}

class WorldTheme {
  const WorldTheme(this.top, this.bottom, this.board, this.icon);
  final Color top;
  final Color bottom;
  final Color board;
  final IconData icon;

  static const _themes = {
    'candy': WorldTheme(Color(0xFFFF9AC9), Color(0xFFFFD1E6), Color(0xFF7A3E7F), Icons.cake_rounded),
    'forest': WorldTheme(Color(0xFF4CC38A), Color(0xFFBDF2D5), Color(0xFF2F5B47), Icons.forest_rounded),
    'ocean': WorldTheme(Color(0xFF3AA0FF), Color(0xFFBFE3FF), Color(0xFF1F4E7A), Icons.water_rounded),
    'desert': WorldTheme(Color(0xFFFFB054), Color(0xFFFFE3B8), Color(0xFF7A5226), Icons.wb_sunny_rounded),
    'snow': WorldTheme(Color(0xFF8FB8FF), Color(0xFFE8F1FF), Color(0xFF3D4F7A), Icons.ac_unit_rounded),
    'space': WorldTheme(Color(0xFF5B3FD6), Color(0xFF2A1F66), Color(0xFF1A1440), Icons.rocket_launch_rounded),
    'entrance': WorldTheme(Color(0xFF7FD6A4), Color(0xFFD7F5E3), Color(0xFF3D6B52), Icons.door_sliding_rounded),
  };
  static WorldTheme of(String key) => _themes[key] ?? _themes['candy']!;
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    secondary: AppColors.accent,
    surface: AppColors.surface,
    brightness: Brightness.light,
  );
  const ink = AppColors.ink;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    textTheme: const TextTheme(
      displaySmall: TextStyle(fontWeight: FontWeight.w900, color: ink, letterSpacing: -0.5),
      headlineSmall: TextStyle(fontWeight: FontWeight.w900, color: ink),
      titleLarge: TextStyle(fontWeight: FontWeight.w800, color: ink),
      titleMedium: TextStyle(fontWeight: FontWeight.w800, color: ink),
      bodyLarge: TextStyle(fontWeight: FontWeight.w600, color: ink),
      bodyMedium: TextStyle(fontWeight: FontWeight.w500, color: ink),
      labelLarge: TextStyle(fontWeight: FontWeight.w800),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: ink,
      centerTitle: true,
      titleTextStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: ink),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      backgroundColor: AppColors.surface,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      showDragHandle: true,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primary.withValues(alpha: 0.14),
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
      height: 68,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
