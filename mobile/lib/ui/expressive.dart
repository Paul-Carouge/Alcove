// Material 3 Expressive pieces that Flutter 3.44 does not ship yet, rebuilt with standard
// Flutter (springs, ShapeBorder, CustomPainter). Colours come from the Lin tokens.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../theme/theme.dart';
import '../theme/tokens.g.dart';

// ---------------------------------------------------------------------------------------------
// Motion: M3 Expressive spring tokens.
// ---------------------------------------------------------------------------------------------

/// A [Curve] that follows a critically-tuned spring from 0 to 1, so implicit animations
/// (AnimatedContainer, AnimatedScale…) move like M3 Expressive springs.
class SpringCurve extends Curve {
  const SpringCurve(this.spring, this.settle);

  final SpringDescription spring;

  /// Seconds the curve's 0..1 range covers (the spring is settled by then).
  final double settle;

  @override
  double transformInternal(double t) => SpringSimulation(spring, 0, 1, 0).x(t * settle);
}

/// The M3 Expressive motion scheme: spatial springs (may overshoot a little) for things that
/// move or change shape, effects springs (no bounce) for colour and opacity.
abstract final class AlcoveSprings {
  static final SpringDescription _fast = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 1400,
    ratio: 0.9,
  );
  static final SpringDescription _default = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 700,
    ratio: 0.9,
  );
  static final SpringDescription _slow = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 300,
    ratio: 0.9,
  );

  static final Curve fastSpatial = SpringCurve(_fast, 0.2);
  static final Curve spatial = SpringCurve(_default, 0.32);
  static final Curve slowSpatial = SpringCurve(_slow, 0.5);

  static const Duration fast = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 500);

  /// [d], or zero when the user asked the system to reduce motion.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false ? Duration.zero : d;
}

// ---------------------------------------------------------------------------------------------
// Shapes: the Expressive shape library (cookie, sunny, burst…), as polar ShapeBorders.
// ---------------------------------------------------------------------------------------------

/// A rounded, scalloped shape defined in polar coordinates: [lobes] soft bumps of relative
/// [depth] around a circle. lobes 0 is a circle; 9 lobes at 0.07 is the "cookie" shape.
@immutable
class PolarShape {
  const PolarShape(this.lobes, this.depth, [this.squash = 0]);

  final int lobes;
  final double depth;

  /// Flattens the shape vertically (0 = round), for the pill/oval steps of the loader.
  final double squash;

  /// Radius (0..1) at angle [a].
  double radius(double a) {
    final scallop = lobes == 0 ? 1.0 : 1 - depth * (1 - math.cos(lobes * a)) / 2;
    final oval = 1 - squash * math.pow(math.sin(a), 2);
    return scallop * oval;
  }

  static const circle = PolarShape(0, 0);
  static const cookie = PolarShape(9, 0.07);
  static const sunny = PolarShape(8, 0.1);
  static const softBurst = PolarShape(10, 0.12);
  static const pentagon = PolarShape(5, 0.08);
  static const clover = PolarShape(4, 0.26);
  static const oval = PolarShape(0, 0, 0.32);

  /// The sequence of M3 Expressive's loading indicator.
  static const loader = [softBurst, cookie, pentagon, oval, sunny, clover];
}

Path _polarPath(Rect rect, double Function(double) r, {double rotation = 0, int steps = 144}) {
  final c = rect.center;
  final scale = rect.shortestSide / 2;
  final path = Path();
  for (var i = 0; i <= steps; i++) {
    final a = i / steps * math.pi * 2;
    final p = c + Offset(math.cos(a + rotation), math.sin(a + rotation)) * (r(a) * scale);
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

/// A [ShapeBorder] for a [PolarShape], to clip avatars and badges into Expressive shapes.
class PolarShapeBorder extends OutlinedBorder {
  const PolarShapeBorder(this.shape, {super.side, this.rotation = 0});

  final PolarShape shape;
  final double rotation;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _polarPath(rect, shape.radius, rotation: rotation);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(side.strokeInset), textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(getOuterPath(rect.deflate(side.width / 2)), side.toPaint());
  }

  @override
  PolarShapeBorder copyWith({BorderSide? side}) =>
      PolarShapeBorder(shape, side: side ?? this.side, rotation: rotation);

  @override
  ShapeBorder scale(double t) => PolarShapeBorder(shape, side: side.scale(t), rotation: rotation);
}

// ---------------------------------------------------------------------------------------------
// Loading indicator: a shape that morphs and turns (M3 Expressive LoadingIndicator).
// ---------------------------------------------------------------------------------------------

/// The Expressive loading indicator: a soft shape morphing through the shape library while it
/// turns. [contained] puts it on a tonal circle. With reduced motion it only turns, slowly.
class LoadingIndicator extends StatefulWidget {
  const LoadingIndicator({super.key, this.size = 48, this.contained = false, this.color});

  final double size;
  final bool contained;
  final Color? color;

  @override
  State<LoadingIndicator> createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<LoadingIndicator> with SingleTickerProviderStateMixin {
  static const _perShape = 650; // ms per morph step
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _perShape * 6),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final color = widget.color ?? c.accent;
    return Semantics(
      label: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
      child: SizedBox.square(
        dimension: widget.size,
        child: DecoratedBox(
          decoration: widget.contained
              ? BoxDecoration(color: c.accentSubtle, shape: BoxShape.circle)
              : const BoxDecoration(),
          child: Padding(
            padding: EdgeInsets.all(widget.size * (widget.contained ? 0.2 : 0.1)),
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, _) => CustomPaint(
                  painter: _LoaderPainter(reduce ? 0 : _c.value, _c.value, color),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoaderPainter extends CustomPainter {
  _LoaderPainter(this.morph, this.turn, this.color);
  final double morph; // 0..1 over the whole sequence (0 = no morphing)
  final double turn;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const shapes = PolarShape.loader;
    final pos = morph * shapes.length;
    final i = pos.floor() % shapes.length;
    final next = shapes[(i + 1) % shapes.length];
    // Each step holds, then springs into the next shape.
    final local = (pos - pos.floor());
    final t = local < 0.45 ? 0.0 : AlcoveSprings.fastSpatial.transform((local - 0.45) / 0.55);
    final from = shapes[i];
    double r(double a) => from.radius(a) + (next.radius(a) - from.radius(a)) * t;
    canvas.drawPath(
      _polarPath(Offset.zero & size, r, rotation: turn * math.pi * 2 * 3),
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_LoaderPainter old) =>
      old.morph != morph || old.turn != turn || old.color != color;
}

// ---------------------------------------------------------------------------------------------
// Floating toolbar.
// ---------------------------------------------------------------------------------------------

/// A pill of actions that floats over content (M3 Expressive floating toolbar).
class FloatingToolbar extends StatelessWidget {
  const FloatingToolbar({
    super.key,
    required this.children,
    this.color,
    this.foreground,
    this.border,
  });

  final List<Widget> children;
  final Color? color;
  final Color? foreground;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = foreground ?? c.text;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: color ?? c.surfaceRaised,
        shape: StadiumBorder(side: BorderSide(color: border ?? c.border)),
        shadows: c.shadowLG,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AlcoveSpace.s1),
        child: IconButtonTheme(
          data: IconButtonThemeData(
            style: IconButton.styleFrom(
              foregroundColor: fg,
              minimumSize: const Size(52, 52),
              shape: const StadiumBorder(),
            ),
          ),
          child: IconTheme(
            data: IconThemeData(color: fg),
            child: Row(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Button group: the pressed button grows, its neighbours make room.
// ---------------------------------------------------------------------------------------------

/// A standard M3 Expressive button group: buttons share the width; the pressed one widens
/// with a spring while its neighbours give way.
class ButtonGroup extends StatefulWidget {
  const ButtonGroup({super.key, required this.children, this.flex});

  final List<Widget> children;

  /// Relative widths at rest (defaults to equal).
  final List<double>? flex;

  @override
  State<ButtonGroup> createState() => _ButtonGroupState();
}

class _ButtonGroupState extends State<ButtonGroup> {
  int? _pressed;

  @override
  Widget build(BuildContext context) {
    final n = widget.children.length;
    final flex = widget.flex ?? List.filled(n, 1.0);
    final duration = AlcoveSprings.of(context, AlcoveSprings.medium);
    return LayoutBuilder(
      builder: (context, box) {
        const gap = AlcoveSpace.s2;
        final width = box.maxWidth - gap * (n - 1);
        final sum = flex.fold(0.0, (a, b) => a + b);
        final widths = [for (final f in flex) width * f / sum];
        if (_pressed case final p? when n > 1) {
          final grow = widths[p] * 0.15;
          for (var i = 0; i < n; i++) {
            widths[i] += i == p ? grow : -grow / (n - 1);
          }
        }
        return Row(
          children: [
            for (var i = 0; i < n; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              AnimatedContainer(
                duration: duration,
                curve: AlcoveSprings.spatial,
                width: widths[i],
                child: Listener(
                  onPointerDown: (_) => setState(() => _pressed = i),
                  onPointerUp: (_) => setState(() => _pressed = null),
                  onPointerCancel: (_) => setState(() => _pressed = null),
                  child: widget.children[i],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------------------------
// FAB menu.
// ---------------------------------------------------------------------------------------------

/// One entry of a [showFabMenu].
class FabMenuItem<T> {
  const FabMenuItem({required this.icon, required this.label, required this.value, this.key});
  final IconData icon;
  final String label;
  final T value;
  final Key? key;
}

/// Opens the M3 Expressive FAB menu from the FAB found at [fabKey]: the FAB morphs into a
/// round close button and the items spring up above it. Returns the chosen value, or null.
Future<T?> showFabMenu<T>(
  BuildContext context, {
  required GlobalKey fabKey,
  required List<FabMenuItem<T>> items,
  required String closeLabel,
}) {
  final box = fabKey.currentContext!.findRenderObject()! as RenderBox;
  final rect = box.localToGlobal(Offset.zero) & box.size;
  HapticFeedback.selectionClick();
  return Navigator.of(context).push<T>(_FabMenuRoute<T>(rect, items, closeLabel));
}

class _FabMenuRoute<T> extends PopupRoute<T> {
  _FabMenuRoute(this.fab, this.items, this.closeLabel);

  final Rect fab;
  final List<FabMenuItem<T>> items;
  final String closeLabel;

  @override
  Color? get barrierColor => null; // drawn by the page, so it fades with the menu

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => closeLabel;

  @override
  Duration get transitionDuration => AlcoveSprings.slow;

  @override
  Duration get reverseTransitionDuration => AlcoveSprings.fast;

  @override
  Widget buildPage(BuildContext context, Animation<double> a, Animation<double> b) {
    return _FabMenu<T>(route: this, animation: a);
  }
}

class _FabMenu<T> extends StatelessWidget {
  const _FabMenu({required this.route, required this.animation});
  final _FabMenuRoute<T> route;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final size = MediaQuery.sizeOf(context);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final fab = route.fab;
    final right = size.width - fab.right;
    final bottom = size.height - fab.bottom;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final v = animation.value;
        final n = route.items.length;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: ColoredBox(color: c.overlay.withValues(alpha: c.overlay.a * v)),
              ),
            ),
            Positioned(
              right: right,
              bottom: bottom + fab.height + AlcoveSpace.s2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < n; i++)
                    Builder(
                      builder: (context) {
                        // The item nearest the FAB comes first.
                        final start = (n - 1 - i) * 0.08;
                        final local = ((v - start) / (1 - start)).clamp(0.0, 1.0);
                        final t = reduce ? v : AlcoveSprings.spatial.transform(local);
                        final item = route.items[i];
                        return Padding(
                          padding: const EdgeInsets.only(top: AlcoveSpace.s2),
                          child: Opacity(
                            opacity: local.clamp(0.0, 1.0),
                            child: Transform.translate(
                              offset: Offset(0, (1 - t) * AlcoveSpace.s5),
                              child: Transform.scale(
                                scale: 0.85 + 0.15 * t,
                                alignment: Alignment.centerRight,
                                child: _FabMenuButton(
                                  key: item.key,
                                  icon: item.icon,
                                  label: item.label,
                                  onTap: () => Navigator.pop(context, item.value),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            // The FAB, morphed from a rounded square into a circle with a close icon.
            Positioned(
              left: fab.left,
              top: fab.top,
              width: fab.width,
              height: fab.height,
              child: Material(
                color: c.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AlcoveRadius.lg + (fab.shortestSide / 2 - AlcoveRadius.lg) * v.clamp(0, 1),
                  ),
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.pop(context),
                  child: Tooltip(
                    message: route.closeLabel,
                    child: Transform.rotate(
                      angle: (1 - v) * -math.pi / 4,
                      child: Icon(Icons.close, color: c.accentContrast),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FabMenuButton extends StatelessWidget {
  const _FabMenuButton({super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.accentSubtle,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AlcoveSpace.s5 - 4,
              AlcoveSpace.s3,
              AlcoveSpace.s5,
              AlcoveSpace.s3,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: c.accent),
                const SizedBox(width: AlcoveSpace.s3),
                Text(
                  label,
                  style: sansStyle(AlcoveFont.sizeMd, c.text, AlcoveFont.semibold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
