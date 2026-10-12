import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.g.dart';

/// Builds Material themes from the generated design tokens so the mobile app
/// matches the web client. Never hard-code colors or sizes in widgets: use
/// `context.colors` and the Alcove* constants.
ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AlcoveColors.dark : AlcoveColors.light;
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.accent,
    onPrimary: c.accentContrast,
    primaryContainer: c.accentSubtle,
    onPrimaryContainer: c.text,
    secondary: c.accent,
    onSecondary: c.accentContrast,
    secondaryContainer: c.accentSubtle,
    onSecondaryContainer: c.accent,
    error: c.danger,
    onError: c.dangerContrast,
    surface: c.surface,
    onSurface: c.text,
    onSurfaceVariant: c.textMuted,
    surfaceContainerLowest: c.surfaceSunken,
    surfaceContainerLow: c.surface,
    surfaceContainer: c.surface,
    surfaceContainerHigh: c.surfaceRaised,
    surfaceContainerHighest: c.surfaceRaised,
    surfaceTint: Colors.transparent,
    outline: c.borderStrong,
    outlineVariant: c.border,
    scrim: c.overlay,
    inverseSurface: c.text,
    onInverseSurface: c.bg,
  );
  const radius = BorderRadius.all(Radius.circular(AlcoveRadius.md));
  const radiusLg = BorderRadius.all(Radius.circular(AlcoveRadius.lg));
  // Headings are tightened like on the web (letter-spacing -0.02em).
  TextStyle heading(double size, [FontWeight weight = AlcoveFont.semibold]) => TextStyle(
    fontFamily: AlcoveFont.sans,
    fontSize: size,
    fontWeight: weight,
    height: AlcoveFont.leadingTight,
    letterSpacing: -size * 0.02,
    color: c.text,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    fontFamily: AlcoveFont.sans,
    extensions: [c],
    splashFactory: InkSparkle.splashFactory,
    textTheme: TextTheme(
      displaySmall: heading(AlcoveFont.sizeXxxl),
      headlineMedium: heading(AlcoveFont.sizeXxl),
      headlineSmall: heading(AlcoveFont.sizeXxl),
      titleLarge: heading(AlcoveFont.sizeXl),
      titleMedium: heading(AlcoveFont.sizeLg),
      titleSmall: heading(AlcoveFont.sizeMd),
      bodyLarge: TextStyle(
        fontSize: AlcoveFont.sizeMd,
        height: AlcoveFont.leadingNormal,
        color: c.text,
      ),
      bodyMedium: TextStyle(
        fontSize: AlcoveFont.sizeSm,
        height: AlcoveFont.leadingNormal,
        color: c.text,
      ),
      bodySmall: TextStyle(
        fontSize: AlcoveFont.sizeXs,
        height: AlcoveFont.leadingNormal,
        color: c.textMuted,
      ),
      labelLarge: const TextStyle(
        fontFamily: AlcoveFont.sans,
        fontSize: AlcoveFont.sizeMd,
        fontWeight: AlcoveFont.medium,
      ),
      labelMedium: const TextStyle(fontSize: AlcoveFont.sizeSm, fontWeight: AlcoveFont.medium),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: heading(AlcoveFont.sizeLg),
      systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: c.accentSubtle,
      height: 68,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: AlcoveFont.sans,
          fontSize: AlcoveFont.sizeXs,
          fontWeight: s.contains(WidgetState.selected) ? AlcoveFont.semibold : AlcoveFont.medium,
          color: s.contains(WidgetState.selected) ? c.text : c.textMuted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: 24,
          color: s.contains(WidgetState.selected) ? c.accent : c.textMuted,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: radiusLg,
        side: BorderSide(color: c.border),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: c.textMuted,
      textColor: c.text,
      contentPadding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s4),
      minVerticalPadding: AlcoveSpace.s3,
      titleTextStyle: TextStyle(
        fontFamily: AlcoveFont.sans,
        fontSize: AlcoveFont.sizeMd,
        fontWeight: AlcoveFont.medium,
        color: c.text,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: AlcoveFont.sans,
        fontSize: AlcoveFont.sizeSm,
        color: c.textMuted,
        height: 1.35,
      ),
    ),
    dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.accentContrast : c.surface,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled)
            ? c.surfaceSunken
            : s.contains(WidgetState.selected)
            ? c.accent
            : c.borderStrong,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.accent,
      linearTrackColor: c.accentSubtle,
      circularTrackColor: c.accentSubtle,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.text,
      contentTextStyle: TextStyle(
        fontFamily: AlcoveFont.sans,
        color: c.bg,
        fontSize: AlcoveFont.sizeSm,
      ),
      shape: const RoundedRectangleBorder(borderRadius: radius),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: c.borderStrong,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AlcoveRadius.lg + 8)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: radiusLg),
      titleTextStyle: heading(AlcoveFont.sizeLg),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AlcoveSpace.s4,
        vertical: AlcoveSpace.s4,
      ),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: c.borderStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: c.focus, width: 2),
      ),
      labelStyle: TextStyle(fontFamily: AlcoveFont.sans, color: c.textMuted),
      floatingLabelStyle: TextStyle(
        fontFamily: AlcoveFont.sans,
        color: c.accent,
        fontWeight: AlcoveFont.medium,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: const RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(
          fontFamily: AlcoveFont.sans,
          fontSize: AlcoveFont.sizeMd,
          fontWeight: AlcoveFont.semibold,
        ),
        animationDuration: AlcoveMotion.fast,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        foregroundColor: c.text,
        shape: const RoundedRectangleBorder(borderRadius: radius),
        side: BorderSide(color: c.borderStrong),
        textStyle: const TextStyle(
          fontFamily: AlcoveFont.sans,
          fontSize: AlcoveFont.sizeMd,
          fontWeight: AlcoveFont.medium,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: c.accent,
        textStyle: const TextStyle(
          fontFamily: AlcoveFont.sans,
          fontSize: AlcoveFont.sizeMd,
          fontWeight: AlcoveFont.medium,
        ),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
  );
}

extension AlcoveThemeContext on BuildContext {
  AlcoveColors get colors => Theme.of(this).extension<AlcoveColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
}
