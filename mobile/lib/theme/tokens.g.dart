// GENERATED from packages/design-tokens/tokens.json. Do not edit.
// ignore_for_file: public_member_api_docs, constant_identifier_names

import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';

/// Theme-dependent tokens (colors, shadows). Read with
/// `Theme.of(context).extension<AlcoveColors>()!`.
@immutable
class AlcoveColors extends ThemeExtension<AlcoveColors> {
  const AlcoveColors({
    required this.bg,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textMuted,
    required this.accent,
    required this.accentHover,
    required this.accentSubtle,
    required this.accentContrast,
    required this.success,
    required this.warning,
    required this.danger,
    required this.dangerContrast,
    required this.focus,
    required this.overlay,
    required this.shadowSM,
    required this.shadowMD,
    required this.shadowLG,
  });

  final Color bg;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceSunken;
  final Color border;
  final Color borderStrong;
  final Color text;
  final Color textMuted;
  final Color accent;
  final Color accentHover;
  final Color accentSubtle;
  final Color accentContrast;
  final Color success;
  final Color warning;
  final Color danger;
  final Color dangerContrast;
  final Color focus;
  final Color overlay;
  final List<BoxShadow> shadowSM;
  final List<BoxShadow> shadowMD;
  final List<BoxShadow> shadowLG;

  static const light = AlcoveColors(
    bg: Color(0xFFF7F8FA),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFEEF0F3),
    border: Color(0xFFDCE0E5),
    borderStrong: Color(0xFFB9C0C9),
    text: Color(0xFF1A1D21),
    textMuted: Color(0xFF535C68),
    accent: Color(0xFF3E5C8A),
    accentHover: Color(0xFF334D75),
    accentSubtle: Color(0xFFE6ECF5),
    accentContrast: Color(0xFFFFFFFF),
    success: Color(0xFF1E7146),
    warning: Color(0xFF9A3F06),
    danger: Color(0xFFB42318),
    dangerContrast: Color(0xFFFFFFFF),
    focus: Color(0xFF3E5C8A),
    overlay: Color(0x661A1D21),
    shadowSM: [BoxShadow(offset: Offset(0, 1), blurRadius: 2, spreadRadius: 0, color: Color(0x0F1A1D21))],
    shadowMD: [BoxShadow(offset: Offset(0, 4), blurRadius: 12, spreadRadius: -2, color: Color(0x1A1A1D21))],
    shadowLG: [BoxShadow(offset: Offset(0, 12), blurRadius: 32, spreadRadius: -4, color: Color(0x241A1D21))],
  );

  static const dark = AlcoveColors(
    bg: Color(0xFF121417),
    surface: Color(0xFF1A1D21),
    surfaceRaised: Color(0xFF22262B),
    surfaceSunken: Color(0xFF0D0F11),
    border: Color(0xFF2E333A),
    borderStrong: Color(0xFF454C55),
    text: Color(0xFFE8EAED),
    textMuted: Color(0xFFA0A8B3),
    accent: Color(0xFF93B2E0),
    accentHover: Color(0xFFAFC6EA),
    accentSubtle: Color(0xFF22324A),
    accentContrast: Color(0xFF0F1A2B),
    success: Color(0xFF5BD394),
    warning: Color(0xFFFDB022),
    danger: Color(0xFFF97066),
    dangerContrast: Color(0xFF1A0B09),
    focus: Color(0xFF93B2E0),
    overlay: Color(0xA3000000),
    shadowSM: [BoxShadow(offset: Offset(0, 1), blurRadius: 2, spreadRadius: 0, color: Color(0x66000000))],
    shadowMD: [BoxShadow(offset: Offset(0, 4), blurRadius: 12, spreadRadius: -2, color: Color(0x80000000))],
    shadowLG: [BoxShadow(offset: Offset(0, 12), blurRadius: 32, spreadRadius: -4, color: Color(0x99000000))],
  );

  @override
  AlcoveColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceSunken,
    Color? border,
    Color? borderStrong,
    Color? text,
    Color? textMuted,
    Color? accent,
    Color? accentHover,
    Color? accentSubtle,
    Color? accentContrast,
    Color? success,
    Color? warning,
    Color? danger,
    Color? dangerContrast,
    Color? focus,
    Color? overlay,
    List<BoxShadow>? shadowSM,
    List<BoxShadow>? shadowMD,
    List<BoxShadow>? shadowLG,
  }) {
    return AlcoveColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      accentHover: accentHover ?? this.accentHover,
      accentSubtle: accentSubtle ?? this.accentSubtle,
      accentContrast: accentContrast ?? this.accentContrast,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      dangerContrast: dangerContrast ?? this.dangerContrast,
      focus: focus ?? this.focus,
      overlay: overlay ?? this.overlay,
      shadowSM: shadowSM ?? this.shadowSM,
      shadowMD: shadowMD ?? this.shadowMD,
      shadowLG: shadowLG ?? this.shadowLG,
    );
  }

  @override
  AlcoveColors lerp(AlcoveColors? other, double t) {
    if (other == null) return this;
    return AlcoveColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentHover: Color.lerp(accentHover, other.accentHover, t)!,
      accentSubtle: Color.lerp(accentSubtle, other.accentSubtle, t)!,
      accentContrast: Color.lerp(accentContrast, other.accentContrast, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerContrast: Color.lerp(dangerContrast, other.dangerContrast, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      shadowSM: BoxShadow.lerpList(shadowSM, other.shadowSM, t)!,
      shadowMD: BoxShadow.lerpList(shadowMD, other.shadowMD, t)!,
      shadowLG: BoxShadow.lerpList(shadowLG, other.shadowLG, t)!,
    );
  }
}

abstract final class AlcoveFont {
  static const String sans = 'Inter';
  static const String mono = 'JetBrains Mono';
  static const double sizeXs = 12;
  static const double sizeSm = 14;
  static const double sizeMd = 16;
  static const double sizeLg = 18;
  static const double sizeXl = 22;
  static const double sizeX2xl = 28;
  static const double sizeX3xl = 36;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const double leadingTight = 1.25;
  static const double leadingNormal = 1.5;
}

abstract final class AlcoveSpace {
  static const double s0 = 0;
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 24;
  static const double s6 = 32;
  static const double s7 = 48;
  static const double s8 = 64;
}

abstract final class AlcoveRadius {
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 16;
  static const double full = 9999;
}

abstract final class AlcoveMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 320);
  static const Curve standardCurve = Cubic(0.2, 0, 0, 1);
  static const Curve emphasizedCurve = Cubic(0.3, 0, 0, 1);
  static const Curve exitCurve = Cubic(0.4, 0, 1, 1);
}

abstract final class AlcoveBreakpoint {
  static const double sm = 600;
  static const double md = 900;
  static const double lg = 1200;
}
