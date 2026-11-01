import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'dex_boot_art.dart';
import 'dex_ornament.dart';

/// True once the startup animation has finished or been skipped. It is a
/// process-wide flag so the animation plays once per cold start, not once per
/// rebuilt widget tree.
final ValueNotifier<bool> dexBootFinished = ValueNotifier<bool>(kDebugMode);

const double _buildStart = 0.3;
const double _buildLength = 1.3;
const double _wordStart = 1.0;
const double _wordSpread = 1.1;
const double _hold = 2.9;
const double _fade = 0.28;

const String _ramp = ' .:-=+*#%@';
const String _flicker = '#%@&\$';
const String _scramble = '@#%&\$*+=-:.';
const String _emberGlyphs = '.\':*';
const int _embers = 36;

int _hash(int x, int y, int t) =>
    ((x * 73856093) ^ (y * 19349663) ^ (t * 83492791)) & 0x7fffffff;

/// The three text layers of one animation frame, as multi-line strings that
/// share one character grid. Pure and deterministic in [t] (seconds).
typedef DexBootFrame = ({String structure, String word, String embers});

DexBootFrame dexBootFrame(double t, {bool scene = true}) {
  final structure = List.generate(
    bootRows,
    (_) => List<String>.filled(bootCols, ' '),
  );
  final word = List.generate(
    bootRows,
    (_) => List<String>.filled(bootCols, ' '),
  );
  final embers = List.generate(
    bootRows,
    (_) => List<String>.filled(bootCols, ' '),
  );

  // Wordmark: each cell scrambles, then locks, centre-out.
  final wcx = (bootWordCols - 1) / 2;
  final wcy = (bootWordRows - 1) / 2;
  final maxDist = math.sqrt(math.pow(wcx / 2.2, 2) + math.pow(wcy, 2));
  final scrambleTick = (t * 24).floor();
  final lockedWord = List.generate(
    bootRows,
    (_) => List<bool>.filled(bootCols, false),
  );
  for (var y = 0; y < bootWordRows; y++) {
    final row = bootWordmark[y];
    for (var x = 0; x < bootWordCols; x++) {
      final level = row.codeUnitAt(x) - 48;
      if (level <= 0) continue;
      final gx = bootWordLeft + x;
      final gy = bootWordTop + y;
      lockedWord[gy][gx] = true;
      final dist =
          math.sqrt(math.pow((x - wcx) / 2.2, 2) + math.pow(y - wcy, 2)) /
          maxDist;
      final reveal = _wordStart + _wordSpread * dist;
      if (t < reveal - 0.4) continue;
      word[gy][gx] = t < reveal
          ? _scramble[_hash(x, y, scrambleTick) % _scramble.length]
          : _ramp[level];
    }
  }

  // Stone: builds from the bottom up and inward; the leading edge flickers.
  final build = ((t - _buildStart) / _buildLength).clamp(0.0, 1.0);
  if (scene && t > _buildStart) {
    for (var y = 0; y < bootRows; y++) {
      final cells = bootStructure[y];
      final orders = bootOrder[y];
      for (var x = 0; x < bootCols; x++) {
        final ch = cells[x];
        if (ch == ' ' || lockedWord[y][x]) continue;
        final r = (orders.codeUnitAt(x) - 48 + 0.5) / 10;
        if (build < r) continue;
        structure[y][x] = build - r < 0.05
            ? _flicker[_hash(x, y, scrambleTick) % _flicker.length]
            : ch;
      }
    }
  }

  // Ash and embers drifting up through the whole scene.
  for (var i = 0; scene && i < _embers; i++) {
    final speed = 0.8 + (i % 4) * 0.35;
    final cycle = (t * speed * 4 + i * 5.3) % (bootRows + 6);
    final y = bootRows - 1 - cycle.floor();
    if (y < 0 || y >= bootRows) continue;
    final sway = (math.sin(t * 1.7 + i * 1.3) * 2).round();
    final x = ((i * 37 + 11) % bootCols + sway) % bootCols;
    if (!lockedWord[y][x]) embers[y][x] = _emberGlyphs[i % _emberGlyphs.length];
  }

  String join(List<List<String>> g) => g.map((r) => r.join()).join('\n');
  return (structure: join(structure), word: join(word), embers: join(embers));
}

/// Startup animation: gothic stonework builds on both sides while the DEX
/// wordmark resolves out of noise between the pillars.
///
/// Any key press, click or tap skips it at once. Under reduced motion it shows
/// the finished frame for a moment and fades out.
class DexBootSplash extends StatefulWidget {
  const DexBootSplash({super.key});

  @override
  State<DexBootSplash> createState() => _DexBootSplashState();
}

class _DexBootSplashState extends State<DexBootSplash>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _time = ValueNotifier<double>(0);
  Duration _lastPaint = Duration.zero;
  double _offset = 0;
  bool _reduced = false;
  bool _started = false;
  ui.Image? _thorn;
  ui.Image? _cross;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _resolve('assets/gothic/thorn_crescent.png', (i) => _thorn = i);
    _resolve('assets/gothic/cross_crescent.png', (i) => _cross = i);
    DexArt.startupAnimation.addListener(_onPreference);
    // The saved choice may already be loaded.
    if (!DexArt.startupAnimation.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
    }
  }

  /// Decodes an asset once and keeps the image for the painter.
  void _resolve(String asset, void Function(ui.Image) done) {
    final stream = AssetImage(asset).resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      stream.removeListener(listener);
      if (mounted) setState(() => done(info.image.clone()));
    }, onError: (_, _) => stream.removeListener(listener));
    stream.addListener(listener);
  }

  /// The user turned the startup animation off: end it at once.
  void _onPreference() {
    if (!DexArt.startupAnimation.value) _finish();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced && !_started) {
      _started = true;
      // Jump to the finished frame; the ticker still drives the fade.
      _offset = _hold - 0.2;
    }
  }

  void _onTick(Duration elapsed) {
    // About 30 frames a second is plenty and halves the paint cost.
    if ((elapsed - _lastPaint).inMilliseconds < 33) return;
    _lastPaint = elapsed;
    final t = elapsed.inMicroseconds / 1e6 + _offset;
    if (t >= _hold + _fade) {
      _finish();
      return;
    }
    _time.value = t;
  }

  void _skip() {
    if (_time.value < _hold) _offset += _hold - _time.value;
    _lastPaint = Duration.zero;
  }

  void _finish() {
    _ticker.stop();
    dexBootFinished.value = true;
  }

  @override
  void dispose() {
    DexArt.startupAnimation.removeListener(_onPreference);
    _ticker.dispose();
    _time.dispose();
    _thorn?.dispose();
    _cross?.dispose();
    super.dispose();
  }

  /// The decoded wordmark only (the scene's other layers are not used).
  static String _wordmark(double t) {
    final rows = dexBootFrame(t, scene: false).word.split('\n');
    return [
      for (var r = bootWordTop; r < bootWordTop + bootWordRows; r++)
        rows[r].substring(bootWordLeft, bootWordLeft + bootWordCols),
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          _skip();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _skip,
        child: ValueListenableBuilder<double>(
          valueListenable: _time,
          builder: (context, t, _) {
            final fade = t <= _hold
                ? 1.0
                : (1 - (t - _hold) / _fade).clamp(0.0, 1.0);
            final pulse = t > 2.3 ? 0.9 + 0.1 * math.sin((t - 2.3) * 6) : 1.0;
            return Opacity(
              opacity: fade,
              child: ColoredBox(
                color: const Color(0xFF050505),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: _SigilPainter(t, _thorn, _cross),
                      size: Size.infinite,
                    ),
                    Align(
                      alignment: const Alignment(0, 0.2),
                      child: Text(
                        _wordmark(t),
                        style: TextStyle(
                          fontFamily: 'Consolas',
                          fontFamilyFallback: const [
                            'Cascadia Mono',
                            'Courier New',
                            'monospace',
                          ],
                          fontSize: 12,
                          height: 1.0,
                          color: const Color(
                            0xFFF2F2F2,
                          ).withValues(alpha: pulse),
                          decoration: TextDecoration.none,
                          shadows: const [
                            Shadow(color: Color(0xFF050505), blurRadius: 6),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

double _ease(double x) {
  final v = x.clamp(0.0, 1.0);
  return 1 - math.pow(1 - v, 3).toDouble();
}

/// The cybersigil scene: a glowing axis, a thorn-crescent sigil that unfolds
/// from it, scan and glitch passes, and a small system readout.
class _SigilPainter extends CustomPainter {
  _SigilPainter(this.t, this.thorn, this.cross);

  final double t;
  final ui.Image? thorn;
  final ui.Image? cross;

  static const _bone = Color(0xFFF2F2F2);
  static const _glitch = [(1.02, 1.07), (1.58, 1.62), (2.12, 2.18)];

  static final Path _spark = Path()
    ..moveTo(0, -1)
    ..quadraticBezierTo(0.07, -0.07, 1, 0)
    ..quadraticBezierTo(0.07, 0.07, 0, 1)
    ..quadraticBezierTo(-0.07, 0.07, -1, 0)
    ..quadraticBezierTo(-0.07, -0.07, 0, -1)
    ..close();

  void _drawImage(
    Canvas canvas,
    ui.Image image,
    Rect dst,
    double alpha, {
    double glow = 0,
    double dx = 0,
  }) {
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final to = dst.shift(Offset(dx, 0));
    if (glow > 0) {
      canvas.drawImageRect(
        image,
        src,
        to,
        Paint()
          ..colorFilter = ColorFilter.mode(
            _bone.withValues(alpha: (alpha * 0.55).clamp(0, 1)),
            BlendMode.srcIn,
          )
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glow),
      );
    }
    canvas.drawImageRect(
      image,
      src,
      to,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = ColorFilter.mode(
          _bone.withValues(alpha: alpha.clamp(0, 1)),
          BlendMode.srcIn,
        ),
    );
  }

  void _text(Canvas canvas, String text, Offset at, double alpha) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Consolas',
          fontFamilyFallback: const ['Cascadia Mono', 'monospace'],
          fontSize: 11,
          letterSpacing: 1.2,
          color: _bone.withValues(alpha: alpha.clamp(0, 1)),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at);
  }

  void _sparkAt(Canvas canvas, Offset at, double scale, double alpha) {
    canvas
      ..save()
      ..translate(at.dx, at.dy)
      ..scale(scale, scale)
      ..drawPath(
        _spark,
        Paint()..color = _bone.withValues(alpha: alpha.clamp(0, 1)),
      )
      ..restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);

    // Fine scan lines over the whole screen.
    final lines = Paint()
      ..color = _bone.withValues(alpha: 0.025)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), lines);
    }

    // The axis: a thread of light growing out from the centre.
    final axis = _ease(t / 0.7);
    final halfH = size.height * 0.46 * axis;
    final settled = _ease((t - 1.6) / 0.8);
    final axisAlpha = 0.9 - 0.62 * settled;
    canvas.drawLine(
      Offset(c.dx, c.dy - halfH),
      Offset(c.dx, c.dy + halfH),
      Paint()
        ..color = _bone.withValues(alpha: axisAlpha * 0.35)
        ..strokeWidth = 7
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawLine(
      Offset(c.dx, c.dy - halfH),
      Offset(c.dx, c.dy + halfH),
      Paint()
        ..color = _bone.withValues(alpha: axisAlpha)
        ..strokeWidth = 1.2,
    );
    if (axis > 0.05) {
      final twinkle = 0.7 + 0.3 * math.sin(t * 9);
      _sparkAt(canvas, Offset(c.dx, c.dy - halfH), 9, twinkle * axis);
      _sparkAt(canvas, Offset(c.dx, c.dy + halfH), 9, twinkle * axis);
    }

    // Flanking sigils, faint and a little behind.
    final side = cross;
    if (side != null && t > 0.9) {
      final p = _ease((t - 0.9) / 1.2);
      final h = size.height * 0.62;
      final w = side.width * h / side.height;
      for (final dir in [-1.0, 1.0]) {
        final centre = Offset(c.dx + dir * size.width * 0.30, c.dy);
        final rect = Rect.fromCenter(center: centre, width: w, height: h);
        canvas.save();
        canvas.clipRect(
          Rect.fromCenter(
            center: centre,
            width: w * p,
            height: h * (0.4 + 0.6 * p),
          ),
        );
        _drawImage(canvas, side, rect, 0.2 * p, glow: 6);
        canvas.restore();
      }
    }

    // The main sigil unfolds from the axis, with bloom, scan and glitch.
    final main = thorn;
    if (main != null && t > 0.4) {
      final p = _ease((t - 0.45) / 1.35);
      final h = size.height * 0.84;
      final w = main.width * h / main.height;
      final dst = Rect.fromCenter(center: c, width: w, height: h);
      canvas.save();
      canvas.clipRect(
        Rect.fromCenter(
          center: c,
          width: w * 1.05 * p,
          height: h * (0.35 + 0.65 * p),
        ),
      );
      _drawImage(canvas, main, dst, p, glow: 16);
      canvas.restore();

      // A bright line sweeping down the sigil.
      final sweep = (t - 0.5) / 1.4;
      if (sweep > 0 && sweep < 1) {
        final y = dst.top + dst.height * sweep;
        final trail = Rect.fromLTRB(dst.left, y - 70, dst.right, y);
        canvas.drawRect(
          trail,
          Paint()
            ..shader = ui.Gradient.linear(trail.topCenter, trail.bottomCenter, [
              _bone.withValues(alpha: 0),
              _bone.withValues(alpha: 0.16),
            ]),
        );
        canvas.drawLine(
          Offset(dst.left, y),
          Offset(dst.right, y),
          Paint()
            ..color = _bone.withValues(alpha: 0.55)
            ..strokeWidth = 1.2,
        );
      }

      // Short glitch passes: horizontal slices knocked sideways.
      for (final (a, b) in _glitch) {
        if (t < a || t > b) continue;
        for (var k = 0; k < 3; k++) {
          final top =
              dst.top +
              dst.height * (0.18 + 0.27 * k + 0.05 * math.sin(t * 90 + k));
          final slice = Rect.fromLTRB(
            dst.left - 20,
            top,
            dst.right + 20,
            top + 18,
          );
          canvas.save();
          canvas.clipRect(slice);
          _drawImage(canvas, main, dst, 0.9, dx: (k.isEven ? 1 : -1) * 12.0);
          canvas.restore();
        }
      }
    }

    // HUD: corner brackets that draw in.
    final bracket = _ease((t - 0.2) / 0.6);
    final corner = Paint()
      ..color = _bone.withValues(alpha: 0.5 * bracket)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    const m = 26.0;
    final len = 34.0 * bracket;
    for (final (sx, sy) in [
      (-1.0, -1.0),
      (1.0, -1.0),
      (-1.0, 1.0),
      (1.0, 1.0),
    ]) {
      final corner0 = Offset(
        c.dx + sx * (size.width / 2 - m),
        c.dy + sy * (size.height / 2 - m),
      );
      canvas.drawLine(corner0, corner0 + Offset(-sx * len, 0), corner);
      canvas.drawLine(corner0, corner0 + Offset(0, -sy * len), corner);
    }

    // System readout, typed out.
    const title = 'INITIALISING SIGIL ENGINE';
    final typed = (t * 26).floor().clamp(0, title.length);
    final cursor = (t * 3).floor().isEven ? '_' : ' ';
    _text(
      canvas,
      '${title.substring(0, typed)}${typed < title.length ? cursor : ''}',
      const Offset(m + 6, m + 6),
      0.6,
    );
    if (t > 1.1) {
      _text(
        canvas,
        'DEX // 0x44 0x45 0x58',
        Offset(m + 6, m + 24),
        0.4 * _ease((t - 1.1) / 0.4),
      );
    }
    final done = (t / 2.6).clamp(0.0, 1.0);
    final filled = (done * 24).round();
    final bar =
        '[${'#' * filled}${'-' * (24 - filled)}] ${(done * 100).round().toString().padLeft(3)}%';
    _text(
      canvas,
      bar,
      Offset(
        size.width - m - 6 - 11 * 0.62 * bar.length - 14,
        size.height - m - 22,
      ),
      0.55,
    );
  }

  @override
  bool shouldRepaint(_SigilPainter old) =>
      old.t != t || old.thorn != thorn || old.cross != cross;
}
