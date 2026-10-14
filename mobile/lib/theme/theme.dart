import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.g.dart';

/// Fraunces, the serif of titles and section headings ("Lin" direction: a calm notebook).
///
/// The font is variable: the optical size follows the font size and a touch of softness
/// rounds its corners. Flutter maps [weight] to the `wght` axis.
TextStyle displayStyle(double size, Color color, {FontWeight weight = AlcoveFont.medium}) =>
    TextStyle(
      fontFamily: AlcoveFont.display,
      fontSize: size,
      fontWeight: weight,
      fontVariations: [
        FontVariation('opsz', size.clamp(9, 144).toDouble()),
        const FontVariation('SOFT', 50),
        const FontVariation('WONK', 0),
      ],
      height: AlcoveFont.leadingTight,
      letterSpacing: -size * 0.012,
      color: color,
    );

/// Inter, the text face, at a given size and weight.
TextStyle sansStyle(double size, Color color, [FontWeight weight = AlcoveFont.regular]) =>
    TextStyle(fontFamily: AlcoveFont.sans, fontSize: size, fontWeight: weight, color: color);

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
    surfaceContainerLow: c.bg,
    surfaceContainer: c.surface,
    surfaceContainerHigh: c.surfaceRaised,
    surfaceContainerHighest: c.surfaceRaised,
    surfaceTint: Colors.transparent,
    outline: c.borderStrong,
    outlineVariant: c.border,
    scrim: c.overlay,
    shadow: c.shadowMD.first.color,
    inverseSurface: c.text,
    onInverseSurface: c.bg,
    inversePrimary: c.accentSubtle,
  );
  const radius = BorderRadius.all(Radius.circular(AlcoveRadius.md));
  const radiusLg = BorderRadius.all(Radius.circular(AlcoveRadius.lg));
  const radiusXl = BorderRadius.all(Radius.circular(AlcoveRadius.xl));
  TextStyle sans(double size, [FontWeight weight = AlcoveFont.regular, Color? color]) =>
      sansStyle(size, color ?? c.text, weight);
  final label = sans(AlcoveFont.sizeMd, AlcoveFont.medium).copyWith(color: null);

  // M3 Expressive buttons are pills that square up while pressed (Material animates the morph).
  final morph = WidgetStateProperty.resolveWith<OutlinedBorder>(
    (s) => s.contains(WidgetState.pressed)
        ? const RoundedRectangleBorder(borderRadius: radius)
        : const StadiumBorder(),
  );
  const morphDuration = Duration(milliseconds: 220);

  OutlineInputBorder field(Color color, [double width = 1]) => OutlineInputBorder(
    borderRadius: radius,
    borderSide: BorderSide(color: color, width: width),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    fontFamily: AlcoveFont.sans,
    extensions: [c],
    splashFactory: InkSparkle.splashFactory,
    splashColor: c.accent.withValues(alpha: 0.08),
    highlightColor: c.text.withValues(alpha: 0.04),
    hoverColor: c.text.withValues(alpha: 0.04),
    focusColor: c.focus.withValues(alpha: 0.16),
    dividerColor: c.border,
    textTheme: TextTheme(
      displayLarge: displayStyle(AlcoveFont.sizeXxxl + 12, c.text, weight: AlcoveFont.regular),
      displayMedium: displayStyle(AlcoveFont.sizeXxxl + 4, c.text, weight: AlcoveFont.regular),
      displaySmall: displayStyle(AlcoveFont.sizeXxxl, c.text, weight: AlcoveFont.regular),
      headlineLarge: displayStyle(AlcoveFont.sizeXxxl, c.text, weight: AlcoveFont.regular),
      headlineMedium: displayStyle(AlcoveFont.sizeXxl + 2, c.text),
      headlineSmall: displayStyle(AlcoveFont.sizeXxl, c.text),
      titleLarge: displayStyle(AlcoveFont.sizeXl, c.text),
      titleMedium: displayStyle(AlcoveFont.sizeLg + 1, c.text),
      titleSmall: sans(AlcoveFont.sizeMd, AlcoveFont.semibold),
      bodyLarge: sans(AlcoveFont.sizeMd).copyWith(height: AlcoveFont.leadingNormal),
      bodyMedium: sans(AlcoveFont.sizeSm + 1).copyWith(height: AlcoveFont.leadingNormal),
      bodySmall: sans(
        AlcoveFont.sizeXs + 1,
        AlcoveFont.regular,
        c.textMuted,
      ).copyWith(height: AlcoveFont.leadingNormal),
      labelLarge: label,
      labelMedium: sans(AlcoveFont.sizeSm, AlcoveFont.medium),
      labelSmall: sans(AlcoveFont.sizeXs, AlcoveFont.medium, c.textMuted),
    ),
    iconTheme: IconThemeData(color: c.text, size: 24),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: AlcoveSpace.s4,
      titleTextStyle: displayStyle(AlcoveFont.sizeXl, c.text),
      iconTheme: IconThemeData(color: c.text, size: 24),
      actionsIconTheme: IconThemeData(color: c.text, size: 24),
      systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.bg,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      indicatorColor: c.accentSubtle,
      indicatorShape: const StadiumBorder(),
      height: 68,
      elevation: 0,
      labelPadding: const EdgeInsets.only(top: AlcoveSpace.s1),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? sans(AlcoveFont.sizeXs, AlcoveFont.semibold)
            : sans(AlcoveFont.sizeXs, AlcoveFont.medium, c.textMuted),
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
      titleTextStyle: sans(AlcoveFont.sizeMd, AlcoveFont.medium),
      subtitleTextStyle: sans(
        AlcoveFont.sizeSm,
        AlcoveFont.regular,
        c.textMuted,
      ).copyWith(height: 1.4),
    ),
    dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? c.accentContrast
            : s.contains(WidgetState.disabled)
            ? c.border
            : c.borderStrong,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? (s.contains(WidgetState.disabled) ? c.accent.withValues(alpha: 0.4) : c.accent)
            : c.surfaceSunken,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? Colors.transparent
            : (s.contains(WidgetState.disabled) ? c.border : c.borderStrong),
      ),
      trackOutlineWidth: WidgetStateProperty.all(1.5),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AlcoveRadius.sm / 2)),
      ),
      side: BorderSide(color: c.borderStrong, width: 1.5),
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.accent : Colors.transparent,
      ),
      checkColor: WidgetStateProperty.all(c.accentContrast),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.accent : c.borderStrong,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surface,
      selectedColor: c.accentSubtle,
      disabledColor: c.surfaceSunken,
      checkmarkColor: c.accent,
      side: BorderSide(color: c.border),
      shape: const StadiumBorder(),
      labelStyle: sans(AlcoveFont.sizeSm, AlcoveFont.medium),
      padding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s2, vertical: AlcoveSpace.s1),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.accent,
      linearTrackColor: c.accentSubtle,
      circularTrackColor: c.accentSubtle,
      refreshBackgroundColor: c.surfaceRaised,
      // The 2024 Material 3 indicators: rounded ends and a gap between track and progress.
      // ignore: deprecated_member_use, the documented opt-in until it becomes the default.
      year2023: false,
    ),
    badgeTheme: BadgeThemeData(backgroundColor: c.accent, smallSize: 8),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: c.text,
        borderRadius: const BorderRadius.all(Radius.circular(AlcoveRadius.sm)),
      ),
      textStyle: sans(AlcoveFont.sizeXs + 1, AlcoveFont.medium, c.bg),
      padding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s3, vertical: AlcoveSpace.s2),
      waitDuration: AlcoveMotion.slow,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.accent,
      foregroundColor: c.accentContrast,
      elevation: 1,
      focusElevation: 2,
      hoverElevation: 2,
      highlightElevation: 2,
      shape: const RoundedRectangleBorder(borderRadius: radiusLg),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.text,
      actionTextColor: c.accentSubtle,
      closeIconColor: c.bg,
      elevation: 0,
      insetPadding: const EdgeInsets.fromLTRB(
        AlcoveSpace.s4,
        AlcoveSpace.s2,
        AlcoveSpace.s4,
        AlcoveSpace.s4,
      ),
      contentTextStyle: sans(AlcoveFont.sizeSm + 1, AlcoveFont.regular, c.bg),
      shape: const RoundedRectangleBorder(borderRadius: radiusLg),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.bg,
      modalBackgroundColor: c.bg,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: c.borderStrong,
      dragHandleSize: const Size(36, 4),
      modalBarrierColor: c.overlay,
      elevation: 0,
      modalElevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AlcoveRadius.xl)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      barrierColor: c.overlay,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: radiusXl,
        side: dark ? BorderSide(color: c.border) : BorderSide.none,
      ),
      titleTextStyle: displayStyle(AlcoveFont.sizeXl, c.text),
      contentTextStyle: sans(
        AlcoveFont.sizeSm + 1,
        AlcoveFont.regular,
        c.textMuted,
      ).copyWith(height: AlcoveFont.leadingNormal),
      actionsPadding: const EdgeInsets.fromLTRB(
        AlcoveSpace.s5,
        0,
        AlcoveSpace.s5,
        AlcoveSpace.s5,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: c.border),
      ),
      textStyle: sans(AlcoveFont.sizeMd),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.accent,
      selectionColor: c.accent.withValues(alpha: 0.24),
      selectionHandleColor: c.accent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AlcoveSpace.s4,
        vertical: AlcoveSpace.s4,
      ),
      border: field(c.border),
      enabledBorder: field(c.border),
      disabledBorder: field(c.border.withValues(alpha: 0.6)),
      focusedBorder: field(c.focus, 1.5),
      errorBorder: field(c.danger),
      focusedErrorBorder: field(c.danger, 1.5),
      prefixIconColor: c.textMuted,
      suffixIconColor: c.textMuted,
      labelStyle: sans(AlcoveFont.sizeMd, AlcoveFont.regular, c.textMuted),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (s) => sans(
          AlcoveFont.sizeMd,
          AlcoveFont.medium,
          s.contains(WidgetState.error)
              ? c.danger
              : (s.contains(WidgetState.focused) ? c.accent : c.textMuted),
        ),
      ),
      hintStyle: sans(AlcoveFont.sizeMd, AlcoveFont.regular, c.textMuted),
      helperStyle: sans(AlcoveFont.sizeXs + 1, AlcoveFont.regular, c.textMuted),
      errorStyle: sans(AlcoveFont.sizeXs + 1, AlcoveFont.regular, c.danger),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(56, 56),
        padding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s5),
        backgroundColor: c.accent,
        foregroundColor: c.accentContrast,
        disabledBackgroundColor: c.surfaceSunken,
        disabledForegroundColor: c.textMuted,
        textStyle: sans(AlcoveFont.sizeMd, AlcoveFont.semibold),
        animationDuration: morphDuration,
        elevation: 0,
      ).copyWith(shape: morph),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(56, 56),
        padding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s5),
        foregroundColor: c.text,
        backgroundColor: c.surface,
        disabledForegroundColor: c.textMuted,
        side: BorderSide(color: c.borderStrong),
        textStyle: sans(AlcoveFont.sizeMd, AlcoveFont.semibold),
        animationDuration: morphDuration,
      ).copyWith(shape: morph),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s4),
        foregroundColor: c.accent,
        textStyle: sans(AlcoveFont.sizeMd, AlcoveFont.semibold),
        animationDuration: morphDuration,
      ).copyWith(shape: morph),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: c.text,
        animationDuration: morphDuration,
      ).copyWith(shape: morph),
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
