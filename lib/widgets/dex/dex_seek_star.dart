import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mornye/widgets/dex/dex_motion_field.dart';
import 'package:mornye/widgets/dex/dex_ornament.dart';

/// The seek slider's thumb: a four-pointed star that glows, twinkles and
/// leaves a short light trail along the line as it moves. It swells while
/// music plays and when the slider is pressed.
class DexStarThumbShape extends SliderComponentShape {
  const DexStarThumbShape({this.radius = 9});

  final double radius;

  // A four-pointed spark with concave sides, one unit tall.
  static final Path _spark = Path()
    ..moveTo(0, -1)
    ..quadraticBezierTo(0.1, -0.1, 1, 0)
    ..quadraticBezierTo(0.1, 0.1, 0, 1)
    ..quadraticBezierTo(-0.1, 0.1, -1, 0)
    ..quadraticBezierTo(-0.1, -0.1, 0, -1)
    ..close();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      Size.square(radius * 2);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final color = sliderTheme.activeTrackColor ?? Colors.white;
    final level = DexArt.level.value;
    final lively = level != DexArtworkLevel.off;
    final t = lively ? DexMotionField.time : 0.0;
    final energy = lively ? DexMotionField.energy : 0.0;
    final press = activationAnimation.value;

    final twinkle = 0.5 + 0.5 * math.sin(t * (2.2 + energy * 1.8));
    final size = radius * (1 + 0.14 * twinkle * (0.4 + energy) + 0.45 * press);
    final rtl = textDirection == TextDirection.rtl;

    // A trail fading out behind the star.
    final trail = 46.0 * (0.55 + 0.45 * energy + 0.5 * press);
    final from = center.dx + (rtl ? trail : -trail);
    canvas.drawLine(
      Offset(from, center.dy),
      center,
      Paint()
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [color.withValues(alpha: 0), color.withValues(alpha: 0.55)],
        ).createShader(Rect.fromPoints(Offset(from, center.dy), center)),
    );

    // Soft glow.
    canvas.drawCircle(
      center,
      size * (1.6 + 0.5 * twinkle),
      Paint()
        ..color = color.withValues(alpha: 0.22 + 0.2 * twinkle + 0.15 * press)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // The star: a long cross and a short one turned 45 degrees.
    final fill = Paint()..color = color;
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(math.sin(t * 0.7) * 0.12)
      ..save()
      ..scale(size * 1.25, size * 1.25)
      ..drawPath(_spark, fill)
      ..restore()
      ..rotate(math.pi / 4)
      ..scale(size * 0.62, size * 0.62)
      ..drawPath(_spark, fill..color = color.withValues(alpha: 0.75))
      ..restore();

    // A bright core.
    canvas.drawCircle(
      center,
      size * 0.2,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
  }
}

/// Repaints its child on every tick of the shared motion clock without
/// rebuilding it, so the star can twinkle without invalidating the slider.
class DexMotionRepaint extends SingleChildRenderObjectWidget {
  const DexMotionRepaint({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMotionRepaint();
}

class _RenderMotionRepaint extends RenderProxyBox {
  // Repaints on every tick, so it must not dirty the page it sits in.
  @override
  bool get isRepaintBoundary => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    DexMotionField.frame.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    DexMotionField.frame.removeListener(markNeedsPaint);
    super.detach();
  }
}
