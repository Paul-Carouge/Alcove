import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/theme.dart';
import '../theme/tokens.g.dart';
import 'expressive.dart';

/// The Alcove mark (an arch in a rounded square), drawn like the web's Logo.svelte.
class AlcoveLogo extends StatelessWidget {
  const AlcoveLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return CustomPaint(size: Size.square(size), painter: _LogoPainter(c.accent, c.accentContrast));
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.bg, this.fg);
  final Color bg;
  final Color fg;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 32;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(9 * s)),
      Paint()..color = bg,
    );
    final arch = Path()
      ..moveTo(9 * s, 24 * s)
      ..lineTo(9 * s, 15 * s)
      ..arcToPoint(Offset(23 * s, 15 * s), radius: Radius.circular(7 * s))
      ..lineTo(23 * s, 24 * s);
    canvas.drawPath(
      arch,
      Paint()
        ..color = fg
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6 * s
        ..strokeCap = StrokeCap.round,
    );
    final door = Path()
      ..moveTo(13 * s, 24 * s)
      ..lineTo(13 * s, 17 * s)
      ..arcToPoint(Offset(19 * s, 17 * s), radius: Radius.circular(3 * s))
      ..lineTo(19 * s, 24 * s)
      ..close();
    canvas.drawPath(door, Paint()..color = fg.withValues(alpha: 0.35));
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.bg != bg || old.fg != fg;
}

/// A section heading in the display serif, like a chapter title in a notebook.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing, this.padding});

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          padding ??
          const EdgeInsetsDirectional.fromSTEB(AlcoveSpace.s1, 0, AlcoveSpace.s1, AlcoveSpace.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: context.text.titleMedium),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A group of rows, M3 Expressive style: each row is its own surface, separated by a thin gap
/// of paper; the group's outer corners are large and its inner corners small.
class InsetGroup extends StatelessWidget {
  const InsetGroup({super.key, this.title, required this.children, this.footer});

  final String? title;
  final List<Widget> children;
  final String? footer;

  static const _outer = Radius.circular(AlcoveRadius.xl);
  static const _inner = Radius.circular(AlcoveRadius.sm / 2);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = children.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AlcoveSpace.s4, 0, AlcoveSpace.s4, AlcoveSpace.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) SectionHeader(title: title!),
          for (var i = 0; i < n; i++) ...[
            if (i > 0) const SizedBox(height: 2),
            Material(
              color: c.surface,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  top: i == 0 ? _outer : _inner,
                  bottom: i == n - 1 ? _outer : _inner,
                ),
              ),
              child: children[i],
            ),
          ],
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AlcoveSpace.s2,
                AlcoveSpace.s3,
                AlcoveSpace.s2,
                0,
              ),
              child: Text(
                footer!,
                style: TextStyle(
                  color: c.textMuted,
                  fontSize: AlcoveFont.sizeXs + 1,
                  height: AlcoveFont.leadingNormal,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// An icon on a soft tinted square: the leading mark of list rows.
class TintedIcon extends StatelessWidget {
  const TintedIcon({super.key, required this.icon, required this.color, this.size = 40});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(AlcoveRadius.md),
      ),
      child: Icon(icon, size: size * 0.55, color: color),
    );
  }
}

/// A row of an [InsetGroup]: tinted icon, title, optional subtitle and trailing widget.
class GroupTile extends StatelessWidget {
  const GroupTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.tint,
    this.danger = false,
    this.chevron = true,
  });

  /// Shows a chevron on tappable rows that lead somewhere (not on actions in a sheet).
  final bool chevron;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? tint;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = danger ? c.danger : (tint ?? c.accent);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s4, vertical: AlcoveSpace.s3),
          child: Row(
            children: [
              TintedIcon(icon: icon, color: color),
              const SizedBox(width: AlcoveSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: AlcoveFont.sizeMd,
                        fontWeight: AlcoveFont.medium,
                        height: 1.3,
                        color: danger ? c.danger : c.text,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: AlcoveFont.sizeSm,
                          color: c.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AlcoveSpace.s2),
                trailing!,
              ] else if (onTap != null && !danger && chevron)
                Icon(Icons.chevron_right, color: c.borderStrong),
            ],
          ),
        ),
      ),
    );
  }
}

/// The title (and optional line of context) at the top of a bottom sheet.
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.title, this.subtitle, this.leading});

  final String title;
  final String? subtitle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AlcoveSpace.s5,
        AlcoveSpace.s1,
        AlcoveSpace.s5,
        AlcoveSpace.s4,
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: AlcoveSpace.s3)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleLarge,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: AlcoveSpace.s1),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.textMuted, fontSize: AlcoveFont.sizeSm),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon in a soft circle, title and explanation: for empty lists and errors.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.body, this.action});

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AlcoveSpace.s6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: ShapeDecoration(
                  color: c.accentSubtle,
                  shape: const PolarShapeBorder(PolarShape.sunny),
                ),
                child: Icon(icon, size: 36, color: c.accent),
              ),
              const SizedBox(height: AlcoveSpace.s5),
              Text(title, textAlign: TextAlign.center, style: context.text.titleLarge),
              if (body != null) ...[
                const SizedBox(height: AlcoveSpace.s2),
                Text(
                  body!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: c.textMuted,
                    fontSize: AlcoveFont.sizeSm + 1,
                    height: AlcoveFont.leadingNormal,
                  ),
                ),
              ],
              if (action != null) ...[const SizedBox(height: AlcoveSpace.s5), action!],
            ],
          ),
        ),
      ),
    );
  }
}

/// A softly pulsing placeholder block while content loads (still when motion is reduced).
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.radius = AlcoveRadius.sm});

  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduce = MediaQuery.of(context).disableAnimations;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => DecoratedBox(
        decoration: BoxDecoration(
          color: Color.lerp(c.surfaceSunken, c.border, reduce ? 0.3 : _c.value * 0.6),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// A circular progress ring with content in the middle.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.child,
    this.size = 112,
    this.stroke = 6,
  });

  /// 0..1, or null for indeterminate.
  final double? value;
  final Widget child;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (value == null)
            LoadingIndicator(size: size * 0.6)
          else
            CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(value!.clamp(0, 1), c.accent, c.accentSubtle, stroke),
            ),
          child,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.fg, this.bg, this.stroke);
  final double value;
  final Color fg;
  final Color bg;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = bg
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (value <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      Paint()
        ..color = fg
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.fg != fg || old.bg != bg || old.stroke != stroke;
}

/// User initials, set in the serif, on a soft accent "cookie" (an Expressive shape).
class AlcoveAvatar extends StatelessWidget {
  const AlcoveAvatar({super.key, required this.name, required this.email, this.size = 40});

  final String name;
  final String email;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final initials = (name.trim().isNotEmpty ? name : email)
        .split(RegExp(r'[\s@._-]+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: c.accentSubtle,
        shape: const PolarShapeBorder(PolarShape.cookie),
      ),
      child: Text(initials, style: displayStyle(size * 0.38, c.accent)),
    );
  }
}

/// The header of a screen, like M3 Expressive's flexible top app bar but compact: the serif title
/// sits on the same row as the actions, right under the status bar, and settles to a smaller size
/// as the content scrolls (a hairline appears once content passes under it). No empty toolbar row
/// above the title.
class LargeTitleAppBar extends StatelessWidget {
  const LargeTitleAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;

  static const double _toolbar = kToolbarHeight;
  static const double _grow = AlcoveSpace.s4;
  static const double _subtitleHeight = 22;
  static const double _bigSize = AlcoveFont.sizeXxl + 2;
  static const double _smallSize = AlcoveFont.sizeLg + 2;

  /// Where a RefreshIndicator above this header should start (below the collapsed bar).
  static double edgeOffset(BuildContext context) => MediaQuery.paddingOf(context).top + _toolbar;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final route = ModalRoute.of(context);
    final lead = leading ?? ((route?.impliesAppBarDismissal ?? false) ? const BackButton() : null);
    // The title follows the text size setting, within what the header can hold.
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    return SliverAppBar(
      pinned: true,
      toolbarHeight: _toolbar,
      expandedHeight: _toolbar + _grow + (subtitle == null ? 0 : _subtitleHeight),
      automaticallyImplyLeading: false,
      backgroundColor: c.bg,
      titleSpacing: 0,
      flexibleSpace: Builder(
        builder: (context) {
          final s = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>()!;
          final range = s.maxExtent - s.minExtent;
          final t = range <= 0
              ? 0.0
              : ((s.currentExtent - s.minExtent) / range).clamp(0.0, 1.0).toDouble();
          final size = _smallSize + (_bigSize - _smallSize) * t;
          return Padding(
            padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (lead != null)
                      Align(
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 56,
                          height: _toolbar,
                          child: Center(child: lead),
                        ),
                      )
                    else
                      const SizedBox(width: AlcoveSpace.s4),
                    Expanded(
                      // Title (and subtitle) centred on the actions, at any height of the bar.
                      child: ClipRect(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textScaler: scaler,
                                  style: displayStyle(size, c.text),
                                ),
                              ),
                              if (subtitle != null)
                                SizedBox(
                                  height: _subtitleHeight * t,
                                  child: Opacity(
                                    opacity: ((t - 0.5) * 2).clamp(0.0, 1.0).toDouble(),
                                    child: Text(
                                      subtitle!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textScaler: scaler,
                                      style: TextStyle(
                                        color: c.textMuted,
                                        fontSize: AlcoveFont.sizeSm,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (actions.isNotEmpty)
                      Align(
                        alignment: Alignment.center,
                        child: SizedBox(
                          height: _toolbar,
                          child: Row(mainAxisSize: MainAxisSize.min, children: actions),
                        ),
                      ),
                    const SizedBox(width: AlcoveSpace.s1),
                  ],
                ),
                PositionedDirectional(
                  start: 0,
                  end: 0,
                  bottom: 0,
                  child: Opacity(
                    opacity: (1 - t * 4).clamp(0.0, 1.0).toDouble(),
                    child: Divider(height: 1, color: c.border),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The logo and product name at the top of the sign-in screens.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        const AlcoveLogo(size: 36),
        const SizedBox(width: AlcoveSpace.s3),
        ExcludeSemantics(child: Text(name, style: displayStyle(AlcoveFont.sizeXl + 2, c.text))),
      ],
    );
  }
}
