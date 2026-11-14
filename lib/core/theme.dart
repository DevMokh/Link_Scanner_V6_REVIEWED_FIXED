import 'package:flutter/material.dart';

import 'models.dart';

/// Link Scanner V5 — Cyber-Glass & Precision Intelligence design system.
/// All legacy aliases stay available so existing screens and services remain compatible.
class C {
  C._();

  static const Color backgroundPrimary = Color(0xFF070B14);
  static const Color backgroundSecondary = Color(0xFF0F172A);
  static const Color surfaceGlass = Color(0xA61E293B);
  static const Color borderGlass = Color(0xFF334155);
  static const Color accentPrimary = Color(0xFF6366F1);
  static const Color statusCyan = Color(0xFF06B6D4);
  static const Color statusSafe = Color(0xFF10B981);
  static const Color statusWarning = Color(0xFFF59E0B);
  static const Color statusDanger = Color(0xFFEF4444);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);

  // Backwards-compatible aliases used throughout the existing application.
  static const Color bg = backgroundPrimary;
  static const Color surface = surfaceGlass;
  static const Color surface2 = backgroundSecondary;
  static const Color line = borderGlass;
  static const Color accent = accentPrimary;
  static const Color accentDeep = Color(0xFF4F46E5);
  static const Color secondary = statusCyan;
  static const Color green = statusSafe;
  static const Color amber = statusWarning;
  static const Color orange = Color(0xFFF97316);
  static const Color red = statusDanger;
  static const Color text = textPrimary;
  static const Color muted = textSecondary;
  static const Color onAccent = Color(0xFFFFFFFF);
}

Color alpha(Color c, double o) => c.withAlpha((o.clamp(0, 1) * 255).round());

List<BoxShadow> glow(
  Color c, {
  double opacity = 0.18,
  double blur = 18,
  double spread = 0,
}) => <BoxShadow>[
      BoxShadow(
        color: alpha(c, opacity * 0.55),
        blurRadius: blur,
        spreadRadius: spread,
      ),
    ];

BoxDecoration glassDecoration({
  Color? border,
  double radius = 18,
  bool glowing = false,
}) {
  final edge = border ?? alpha(C.borderGlass, 0.72);
  return BoxDecoration(
    color: alpha(C.surfaceGlass, 0.78),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: edge, width: 1),
    boxShadow: glowing ? glow(border ?? C.accent, opacity: 0.14, blur: 22) : null,
  );
}

Color riskColorForScore(num score) {
  final value = score.clamp(0, 100).toDouble();
  if (value <= 45) {
    return Color.lerp(C.statusCyan, C.statusWarning, value / 45)!;
  }
  return Color.lerp(C.statusWarning, C.statusDanger, (value - 45) / 55)!;
}

Color levelColor(RiskLevel l) {
  switch (l) {
    case RiskLevel.low:
      return C.green;
    case RiskLevel.medium:
      return C.amber;
    case RiskLevel.high:
      return C.orange;
    case RiskLevel.critical:
      return C.red;
  }
}

Color severityColor(Severity s) {
  switch (s) {
    case Severity.good:
      return C.green;
    case Severity.info:
      return C.muted;
    case Severity.warn:
      return C.amber;
    case Severity.danger:
      return C.red;
  }
}

IconData severityIcon(Severity s) {
  switch (s) {
    case Severity.good:
      return Icons.check_circle_rounded;
    case Severity.info:
      return Icons.info_rounded;
    case Severity.warn:
      return Icons.warning_amber_rounded;
    case Severity.danger:
      return Icons.dangerous_rounded;
  }
}

String fmtTime(DateTime t) {
  String two(int n) => n < 10 ? '0$n' : '$n';
  return '${t.day}/${t.month}  ${two(t.hour)}:${two(t.minute)}';
}

ThemeData buildTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: C.accentPrimary,
    brightness: Brightness.dark,
  );
  final scheme = base.copyWith(
    primary: C.accentPrimary,
    onPrimary: C.onAccent,
    secondary: C.statusCyan,
    surface: C.backgroundSecondary,
    onSurface: C.textPrimary,
    error: C.statusDanger,
    surfaceContainerLowest: C.backgroundPrimary,
    surfaceContainerLow: C.backgroundSecondary,
    surfaceContainer: C.backgroundSecondary,
    surfaceContainerHigh: C.surfaceGlass,
    surfaceContainerHighest: C.surfaceGlass,
    outline: C.borderGlass,
    outlineVariant: alpha(C.borderGlass, 0.65),
  );
  final textTheme = ThemeData.dark().textTheme.apply(
    bodyColor: C.textPrimary,
    displayColor: C.textPrimary,
    fontFamily: 'sans-serif',
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: C.backgroundPrimary,
    visualDensity: VisualDensity.standard,
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: C.backgroundPrimary,
      foregroundColor: C.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: C.backgroundPrimary,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: C.surfaceGlass,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: alpha(C.borderGlass, 0.72)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: alpha(C.backgroundSecondary, 0.92),
      indicatorColor: alpha(C.accentPrimary, 0.18),
      surfaceTintColor: Colors.transparent,
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
        final on = states.contains(WidgetState.selected);
        return IconThemeData(color: on ? C.accentPrimary : C.textSecondary, size: 22);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
        final on = states.contains(WidgetState.selected);
        return TextStyle(
          color: on ? C.accentPrimary : C.textSecondary,
          fontSize: 11,
          fontWeight: on ? FontWeight.w800 : FontWeight.w500,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: alpha(C.backgroundPrimary, 0.76),
      hintStyle: const TextStyle(color: C.textSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: alpha(C.borderGlass, 0.85)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: alpha(C.borderGlass, 0.85)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: C.accentPrimary, width: 1.5),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color>((states) =>
          states.contains(WidgetState.selected) ? Colors.white : C.textSecondary),
      trackColor: WidgetStateProperty.resolveWith<Color>((states) =>
          states.contains(WidgetState.selected) ? C.accentPrimary : C.backgroundSecondary),
      trackOutlineColor: WidgetStateProperty.resolveWith<Color>((states) =>
          states.contains(WidgetState.selected) ? C.accentPrimary : C.borderGlass),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: C.accentPrimary,
      inactiveTrackColor: C.borderGlass,
      thumbColor: C.accentPrimary,
      overlayColor: alpha(C.accentPrimary, 0.14),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: C.accentPrimary,
      linearTrackColor: C.backgroundSecondary,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: C.accentPrimary,
      selectionHandleColor: C.accentPrimary,
      selectionColor: alpha(C.accentPrimary, 0.26),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: C.accentPrimary),
    ),
    dividerTheme: DividerThemeData(color: alpha(C.borderGlass, 0.55), space: 1),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: C.backgroundSecondary,
      contentTextStyle: TextStyle(color: C.textPrimary),
    ),
  );
}
