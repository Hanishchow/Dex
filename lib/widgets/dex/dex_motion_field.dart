import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mornye/providers/music_player_provider.dart';
import 'package:mornye/widgets/dex/dex_ornament.dart';

/// The shared clock behind Dex's moving artwork.
///
/// One timer, about 10 frames a second, advances [time], eases the pointer
/// toward where the mouse is, and eases [energy] toward 1 while music plays.
/// Every animated ornament listens to [frame] and reads these values, so the
/// whole interface moves together and the cost does not grow with the number
/// of ornaments.
abstract final class DexMotionField {
  /// Bumped once per tick, after the values below have been updated.
  static final ValueNotifier<int> frame = ValueNotifier<int>(0);

  /// Seconds since the field started.
  static double time = 0;

  /// The mouse, eased, in -1..1 on each axis (0,0 is the window centre).
  static Offset pointer = Offset.zero;

  /// 0 when paused, easing to 1 while music plays.
  static double energy = 0;

  /// Window size, for placing things by pointer.
  static Size size = const Size(1280, 800);

  static Offset _target = Offset.zero;
  static bool _playing = false;
}

/// Hosts the [DexMotionField]. Place it once, around the whole app. It does
/// not change layout or take input: the pointer is read through a translucent
/// listener.
class DexMotionHost extends ConsumerStatefulWidget {
  const DexMotionHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DexMotionHost> createState() => _DexMotionHostState();
}

class _DexMotionHostState extends ConsumerState<DexMotionHost>
    with WidgetsBindingObserver {
  // A plain timer, not a Ticker: a running Ticker asks for a frame on every
  // vsync, so the whole window (blurs included) was re-rendered 60 times a
  // second. The timer produces a frame only when it fires.
  Timer? _timer;
  final Stopwatch _clock = Stopwatch();
  Duration _last = Duration.zero;
  bool _focused = true;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DexArt.level.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Losing focus keeps the window on screen, so it keeps moving; only a
    // minimised or hidden window stops.
    final visible =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    if (!visible && _focused) {
      // Free decoded artwork while nothing can be seen; it reloads on return.
      PaintingBinding.instance.imageCache.clear();
    }
    _focused = visible;
    _sync();
  }

  /// Run only while something can be seen moving.
  void _sync() {
    final run =
        _focused && !_reduced && DexArt.level.value != DexArtworkLevel.off;
    if (run && _timer == null) {
      _clock.start();
      _timer = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => _onTick(_clock.elapsed),
      );
    } else if (!run && _timer != null) {
      _timer!.cancel();
      _timer = null;
      _clock.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    // Frame-rate independent easing toward the targets.
    final follow = 1 - math.exp(-dt * 5);
    DexMotionField.pointer = Offset.lerp(
      DexMotionField.pointer,
      DexMotionField._target,
      follow,
    )!;
    final goal = DexMotionField._playing ? 1.0 : 0.0;
    DexMotionField.energy +=
        (goal - DexMotionField.energy) * (1 - math.exp(-dt * 1.6));
    DexMotionField.time = elapsed.inMicroseconds / 1e6;
    DexMotionField.frame.value++;
  }

  void _onPointer(PointerEvent event) {
    final size = DexMotionField.size;
    if (size.isEmpty) return;
    DexMotionField._target = Offset(
      (event.localPosition.dx / size.width * 2 - 1).clamp(-1.0, 1.0),
      (event.localPosition.dy / size.height * 2 - 1).clamp(-1.0, 1.0),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DexArt.level.removeListener(_sync);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    DexMotionField._playing = ref.watch(playbackPlayingProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        DexMotionField.size = constraints.biggest;
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerHover: _onPointer,
          onPointerMove: _onPointer,
          child: widget.child,
        );
      },
    );
  }
}

/// Small four-pointed sparks drifting up through the whole window, pushed
/// gently away from the mouse. Drawn in one painter, repainted on the shared
/// frame, and invisible when artwork is Off.
class DexEmberField extends StatelessWidget {
  const DexEmberField({super.key, this.count = 26});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DexArtworkLevel>(
      valueListenable: DexArt.level,
      builder: (context, level, _) {
        if (level == DexArtworkLevel.off) return const SizedBox.shrink();
        final dark = Theme.of(context).brightness == Brightness.dark;
        final color = dark ? const Color(0xFFEFE6DD) : const Color(0xFF0A0A0A);
        return IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size.infinite,
              painter: _EmberPainter(
                color: color,
                strength: level == DexArtworkLevel.subtle ? 0.55 : 1.0,
                count: count,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmberPainter extends CustomPainter {
  _EmberPainter({
    required this.color,
    required this.strength,
    required this.count,
  }) : super(repaint: DexMotionField.frame);

  final Color color;
  final double strength;
  final int count;

  // A four-pointed spark with concave sides, one unit tall.
  static final Path _spark = Path()
    ..moveTo(0, -1)
    ..quadraticBezierTo(0.08, -0.08, 1, 0)
    ..quadraticBezierTo(0.08, 0.08, 0, 1)
    ..quadraticBezierTo(-0.08, 0.08, -1, 0)
    ..quadraticBezierTo(-0.08, -0.08, 0, -1)
    ..close();

  static double _hash(int i, double salt) {
    final v = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return v - v.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = DexMotionField.time;
    final pointer = Offset(
      (DexMotionField.pointer.dx + 1) / 2 * size.width,
      (DexMotionField.pointer.dy + 1) / 2 * size.height,
    );
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < count; i++) {
      final speed = 6 + _hash(i, 1) * 16; // px per second, upward
      final sway = 10 + _hash(i, 2) * 26;
      final scale = 2.5 + _hash(i, 3) * 6.5;
      var x = _hash(i, 4) * size.width + math.sin(t * 0.35 + i) * sway;
      var y = (_hash(i, 5) * size.height - t * speed) % size.height;
      if (y < 0) y += size.height;
      // Pushed away from the mouse.
      final away = Offset(x, y) - pointer;
      final d = away.distance;
      if (d < 150 && d > 0.001) {
        final push = (150 - d) / 150 * 34;
        x += away.dx / d * push;
        y += away.dy / d * push;
      }
      final twinkle = 0.55 + 0.45 * math.sin(t * (0.8 + _hash(i, 6) * 1.6) + i);
      final alpha = (0.07 + 0.16 * _hash(i, 7)) * twinkle * strength;
      paint.color = color.withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas
        ..save()
        ..translate(x, y)
        ..scale(scale, scale)
        ..drawPath(_spark, paint)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_EmberPainter old) =>
      old.color != color || old.strength != strength || old.count != count;
}
