import 'dart:math' as math;

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

DexBootFrame dexBootFrame(double t) {
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
  if (t > _buildStart) {
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
  for (var i = 0; i < _embers; i++) {
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

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    DexArt.startupAnimation.addListener(_onPreference);
    // The saved choice may already be loaded.
    if (!DexArt.startupAnimation.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
    }
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
    // About 30 frames a second is plenty for text and halves the layout cost.
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
    super.dispose();
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
            final frame = dexBootFrame(t);
            final fade = t <= _hold
                ? 1.0
                : (1 - (t - _hold) / _fade).clamp(0.0, 1.0);
            final pulse = t > 2.3 ? 0.92 + 0.08 * math.sin((t - 2.3) * 5) : 1.0;
            TextStyle style(double alpha) => TextStyle(
              fontFamily: 'Consolas',
              fontFamilyFallback: const [
                'Cascadia Mono',
                'Courier New',
                'monospace',
              ],
              fontSize: 14,
              height: 1.0,
              color: const Color(0xFFF2F2F2).withValues(alpha: alpha),
              decoration: TextDecoration.none,
            );
            return Opacity(
              opacity: fade,
              child: ColoredBox(
                color: const Color(0xFF050505),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Stack(
                      children: [
                        Text(frame.structure, style: style(0.45)),
                        Text(frame.embers, style: style(0.4)),
                        Text(frame.word, style: style(pulse)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
