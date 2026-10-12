import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/theme.dart';
import '../theme/tokens.g.dart';

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

/// A rounded group of rows, like iOS settings and the web's cards.
class InsetGroup extends StatelessWidget {
  const InsetGroup({super.key, this.title, required this.children, this.footer});

  final String? title;
  final List<Widget> children;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AlcoveSpace.s4, 0, AlcoveSpace.s4, AlcoveSpace.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(AlcoveSpace.s2, 0, 0, AlcoveSpace.s2),
              child: Semantics(
                header: true,
                child: Text(
                  title!.toUpperCase(),
                  style: TextStyle(
                    color: c.textMuted,
                    fontSize: AlcoveFont.sizeXs,
                    fontWeight: AlcoveFont.semibold,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AlcoveRadius.lg),
              border: Border.all(color: c.border),
              boxShadow: c.shadowSM,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AlcoveRadius.lg),
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) const Divider(indent: AlcoveSpace.s4 + 40 + AlcoveSpace.s3),
                      children[i],
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(AlcoveSpace.s2, AlcoveSpace.s2, AlcoveSpace.s2, 0),
              child: Text(
                footer!,
                style: TextStyle(color: c.textMuted, fontSize: AlcoveFont.sizeXs),
              ),
            ),
        ],
      ),
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
  });

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
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s4, vertical: AlcoveSpace.s3),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AlcoveRadius.md),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
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
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AlcoveSpace.s2),
                trailing!,
              ] else if (onTap != null && !danger)
                Icon(Icons.chevron_right, color: c.textMuted),
            ],
          ),
        ),
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
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: c.accentSubtle, shape: BoxShape.circle),
                child: Icon(icon, size: 32, color: c.accent),
              ),
              const SizedBox(height: AlcoveSpace.s4),
              Text(title, textAlign: TextAlign.center, style: context.text.titleMedium),
              if (body != null) ...[
                const SizedBox(height: AlcoveSpace.s2),
                Text(
                  body!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.textMuted, height: 1.45),
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

/// A softly pulsing placeholder block while content loads.
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
  const ProgressRing({super.key, required this.value, required this.child, this.size = 112});

  /// 0..1, or null for indeterminate.
  final double? value;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (value == null)
            SizedBox.expand(child: CircularProgressIndicator(strokeWidth: 8, color: c.accent))
          else
            CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(value!.clamp(0, 1), c.accent, c.accentSubtle),
            ),
          child,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.fg, this.bg);
  final double value;
  final Color fg;
  final Color bg;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
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
  bool shouldRepaint(_RingPainter old) => old.value != value || old.fg != fg;
}

/// User initials on a soft accent circle.
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
      decoration: BoxDecoration(color: c.accentSubtle, shape: BoxShape.circle),
      child: Text(
        initials,
        style: TextStyle(color: c.accent, fontWeight: AlcoveFont.semibold, fontSize: size * 0.36),
      ),
    );
  }
}

/// The header of a main screen: a large title that shrinks into the app bar as the content scrolls.
class LargeTitleAppBar extends StatelessWidget {
  const LargeTitleAppBar({super.key, required this.title, this.actions = const [], this.leading});

  final String title;
  final List<Widget> actions;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SliverAppBar(
      pinned: true,
      expandedHeight: 116,
      leading: leading,
      automaticallyImplyLeading: leading == null,
      backgroundColor: c.bg,
      actions: [
        ...actions,
        const SizedBox(width: AlcoveSpace.s2),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsetsDirectional.only(
          start: leading == null && !Navigator.of(context).canPop() ? AlcoveSpace.s4 : 56,
          bottom: AlcoveSpace.s3 + 2,
        ),
        expandedTitleScale: 1.55,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: AlcoveFont.sans,
            fontSize: 21,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: c.text,
          ),
        ),
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
        Container(
          padding: const EdgeInsets.all(AlcoveSpace.s2),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AlcoveRadius.lg),
            border: Border.all(color: c.border),
            boxShadow: c.shadowSM,
          ),
          child: const AlcoveLogo(size: 36),
        ),
        const SizedBox(width: AlcoveSpace.s3),
        ExcludeSemantics(
          child: Text(
            name,
            style: TextStyle(
              fontFamily: AlcoveFont.sans,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: c.text,
            ),
          ),
        ),
      ],
    );
  }
}
