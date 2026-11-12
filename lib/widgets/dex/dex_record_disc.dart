import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mornye/widgets/cached_cover_image.dart';

/// A brushed-chrome record: bright and dark lobes that sweep round as it
/// turns, fine grooves, a bevelled rim and the album art as its centre label.
/// It turns while [spinning] and keeps its angle when it stops.
class DexRecordDisc extends StatefulWidget {
  const DexRecordDisc({
    super.key,
    required this.size,
    required this.spinning,
    this.coverUrl,
  });

  final double size;
  final bool spinning;
  final String? coverUrl;

  @override
  State<DexRecordDisc> createState() => _DexRecordDiscState();
}

class _DexRecordDiscState extends State<DexRecordDisc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // A slow, lazy turn: one revolution every 3.6 s.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
    if (widget.spinning) _controller.repeat();
  }

  @override
  void didUpdateWidget(DexRecordDisc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.spinning && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final label = s * 0.40;
    final cover = widget.coverUrl;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.rotate(
          angle: _controller.value * math.pi * 2,
          child: child,
        ),
        child: SizedBox.square(
          dimension: s,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: _DiscPainter()),
              ),
              SizedBox.square(
                dimension: label,
                child: ClipOval(
                  child: cover == null
                      ? const ColoredBox(color: Color(0xFFCFCFD4))
                      : CachedCoverImage(imageUrl: cover, memCacheWidth: 220),
                ),
              ),
              const Positioned.fill(child: CustomPaint(painter: _HubPainter())),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscPainter extends CustomPainter {
  const _DiscPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final rect = Rect.fromCircle(center: c, radius: r);

    // Two bright lobes opposite each other, like a lit record.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0xFF151516),
            Color(0xFFB9B9BE),
            Color(0xFFF8F8FA),
            Color(0xFF3A3A3D),
            Color(0xFF101011),
            Color(0xFF8E8E93),
            Color(0xFFEDEDF0),
            Color(0xFF2A2A2D),
            Color(0xFF151516),
          ],
        ).createShader(rect),
    );

    // Y2K holographic wedges: pink, cyan, lime, gold and violet bands that
    // sweep round with the disc, like a CD catching the light.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0x00FFFFFF),
            Color(0x99FF5FD2),
            Color(0x9973E6FF),
            Color(0x99C8FF7A),
            Color(0x99FFE066),
            Color(0x999B6BFF),
            Color(0x00FFFFFF),
            Color(0x00FFFFFF),
            Color(0x88FF8FB8),
            Color(0x8878D8FF),
            Color(0x00FFFFFF),
          ],
        ).createShader(rect),
    );

    // Cool-to-warm fringe at the edge, as in the reference photos.
    canvas.drawCircle(
      c,
      r - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.035
        ..shader = const SweepGradient(
          colors: [
            Color(0x00FFFFFF),
            Color(0x55FF8FB8),
            Color(0x5586E3FF),
            Color(0x55C6FFB0),
            Color(0x00FFFFFF),
          ],
          stops: [0.0, 0.25, 0.5, 0.75, 1.0],
        ).createShader(rect),
    );

    // Fine grooves.
    for (var f = 0.44; f < 0.985; f += 0.012) {
      final dark = ((f * 1000).round() % 2) == 0;
      canvas.drawCircle(
        c,
        r * f,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5
          ..color = dark ? const Color(0x22000000) : const Color(0x14FFFFFF),
      );
    }

    // Frosted clear-plastic hub ring around the label.
    canvas.drawCircle(
      c,
      r * 0.27,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.085
        ..color = const Color(0x55FFFFFF),
    );

    // Raised label ring and bevelled outer edge.
    canvas.drawCircle(
      c,
      r * 0.225,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.03
        ..color = const Color(0xCCEFEFF2),
    );
    canvas.drawCircle(
      c,
      r - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x66FFFFFF),
    );
  }

  @override
  bool shouldRepaint(_DiscPainter oldDelegate) => false;
}

class _HubPainter extends CustomPainter {
  const _HubPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r * 0.045, Paint()..color = const Color(0xFF050506));
    canvas.drawCircle(
      c,
      r * 0.07,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x88FFFFFF),
    );
  }

  @override
  bool shouldRepaint(_HubPainter oldDelegate) => false;
}
