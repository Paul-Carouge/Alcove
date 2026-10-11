import 'package:flutter/material.dart';

import 'tokens.g.dart';

/// Builds Material themes from the generated design tokens so the mobile app
/// matches the web client. Never hard-code colors or sizes in widgets: use
/// `context.colors` and the Alcove* constants.
ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AlcoveColors.dark : AlcoveColors.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.accent,
    onPrimary: c.accentContrast,
    primaryContainer: c.accentSubtle,
    onPrimaryContainer: c.text,
    secondary: c.accent,
    onSecondary: c.accentContrast,
    error: c.danger,
    onError: c.dangerContrast,
    surface: c.surface,
    onSurface: c.text,
    onSurfaceVariant: c.textMuted,
    surfaceContainerLowest: c.surfaceSunken,
    surfaceContainerHighest: c.surfaceRaised,
    outline: c.borderStrong,
    outlineVariant: c.border,
    scrim: c.overlay,
  );
  const radius = BorderRadius.all(Radius.circular(AlcoveRadius.md));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    fontFamily: AlcoveFont.sans,
    extensions: [c],
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontSize: AlcoveFont.sizeXxl,
        fontWeight: AlcoveFont.semibold,
        height: AlcoveFont.leadingTight,
      ),
      titleMedium: TextStyle(
        fontSize: AlcoveFont.sizeLg,
        fontWeight: AlcoveFont.semibold,
        height: AlcoveFont.leadingTight,
      ),
      bodyLarge: TextStyle(fontSize: AlcoveFont.sizeMd, height: AlcoveFont.leadingNormal),
      bodyMedium: TextStyle(fontSize: AlcoveFont.sizeSm, height: AlcoveFont.leadingNormal),
      labelLarge: TextStyle(fontSize: AlcoveFont.sizeMd, fontWeight: AlcoveFont.medium),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: c.borderStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: c.borderStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: c.focus, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: const RoundedRectangleBorder(borderRadius: radius),
        animationDuration: AlcoveMotion.fast,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: const RoundedRectangleBorder(borderRadius: radius),
        side: BorderSide(color: c.borderStrong),
      ),
    ),
  );
}

extension AlcoveThemeContext on BuildContext {
  AlcoveColors get colors => Theme.of(this).extension<AlcoveColors>()!;
}
