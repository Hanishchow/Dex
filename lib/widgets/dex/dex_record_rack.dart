import 'dart:async';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mornye/providers/music_player_provider.dart';
import 'package:mornye/widgets/dex/dex_record_disc.dart';

const _bone = Color(0xFFF2F2F2);
const _ink = Color(0xFF0A0A0A);
const _muted = Color(0xFF9A9A9E);

/// Whether the record rack is folded away; the bottom strip then offers a
/// "Show records" button instead.
final dexRackHidden = ValueNotifier<bool>(false);

double _smooth(double x) {
  final t = x.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// The play queue as a rack of records, ported from the VHS shelf template:
/// records stand side by side, spine out; the focused one turns out in 3D to
/// show its sleeve with a disc sliding out of the top. Click a spine to bring
/// it forward, click the open sleeve to play it, drag or scroll to slide the
/// rack. The title slides up through a mask under the rack.
class DexRecordRack extends ConsumerStatefulWidget {
  const DexRecordRack({super.key, required this.height});

  final double height;

  @override
  ConsumerState<DexRecordRack> createState() => _DexRecordRackState();
}

class _DexRecordRackState extends ConsumerState<DexRecordRack>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  double _s = 0; // scroll position in record units
  double _t = 0; // target
  double _tiltX = 0;
  double _tiltY = 0;
  double _tiltXTarget = 0;
  double _tiltYTarget = 0;
  int _hover = -1;
  final Map<int, double> _lift = {};
  bool _dragging = false;
  bool _dragMoved = false;
  double _dragStartX = 0;
  double _dragT0 = 0;
  Timer? _snapTimer;
  int _dir = 1;
  int _focused = -1;
  List<MediaItem> _items = const [];
  int _current = -1;
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _snapTimer?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  void _kick() {
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  int get _n => _items.length;

  /// Number of copies of the queue so the rack always has records on both
  /// sides, however short the queue is.
  int get _copies => 1;

  int _mod(int a, int n) => ((a % n) + n) % n;

  double _clampT(double t) => t.clamp(0.0, math.max(0, _n - 1).toDouble());

  void _recenter(int index) {
    if (_n == 0) return;
    _t = _clampT(index.toDouble());
    _kick();
  }

  void _onTick(Duration now) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final dt = _last == Duration.zero
        ? 0.016
        : ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = now;
    final k = reduce ? 1.0 : (_dragging ? 18.0 : 5.2);
    final ds = _t - _s;
    var moving = false;
    if (ds.abs() < 1e-4) {
      _s = _t;
    } else {
      _s += ds * (1 - math.exp(-k * dt));
      moving = true;
    }
    final tk = 1 - math.exp(-7 * dt);
    final dx = _tiltXTarget - _tiltX;
    final dy = _tiltYTarget - _tiltY;
    if (dx.abs() > 0.01 || dy.abs() > 0.01) {
      _tiltX += dx * tk;
      _tiltY += dy * tk;
      moving = true;
    }
    final lk = 1 - math.exp(-12 * dt);
    for (final v in _lift.keys.toList()) {
      final target = v == _hover ? 1.0 : 0.0;
      final d = target - _lift[v]!;
      if (d.abs() < 0.003) {
        if (target == 0) {
          _lift.remove(v);
        } else {
          _lift[v] = target;
        }
      } else {
        _lift[v] = _lift[v]! + d * lk;
        moving = true;
      }
    }
    // Keep s within a few loops so numbers stay small.
    final total = _n * _copies;
    if (total > 0 && _s.abs() > total * 2) {
      final shift = (_s / total).round() * total;
      _s -= shift;
      _t -= shift;
    }
    if (mounted) setState(() {});
    if (!moving) _ticker.stop();
  }

  void _moveTarget(double t) {
    final next = _clampT(t);
    _dir = next >= _t ? 1 : -1;
    _t = next;
    _kick();
  }

  void _activate(int v) {
    final n = _n;
    if (n == 0) return;
    final r = _rel(v) - 0.0;
    if (r.abs() < 0.5) {
      final i = _mod(v, n);
      final controller = ref.read(musicPlayerControllerProvider);
      if (i != _current) {
        controller.jumpTo(i);
      } else {
        controller.togglePlayPause(ref.read(playbackPlayingProvider));
      }
    } else {
      _moveTarget((_t + r).roundToDouble());
    }
  }

  double _rel(int v) => v - _s;

  // ---- geometry -----------------------------------------------------------

  _Geo _geo(double width) {
    final h = (widget.height - 92).clamp(96.0, 170.0);
    return _Geo(width: width, h: h, cy: widget.height - 60 - h / 2 - 4);
  }

  double _tapeX(_Geo g, double r) {
    final b = r.abs() < 1
        ? (r + math.sin(math.pi * r) / math.pi) / 2
        : (r < 0 ? -0.5 : 0.5);
    return r * (g.ws + g.gap) + (g.d - g.ws + 1.6 * g.gap) * b;
  }

  int? _tapeAt(_Geo g, Offset p) {
    final total = _n * _copies;
    int? best;
    var bestDist = double.infinity;
    for (var v = 0; v < total; v++) {
      final r = _rel(v);
      final cx = g.width / 2 + _tapeX(g, r);
      final o = _smooth(math.max(0, 1 - r.abs()));
      final half = (g.ws + (g.d - g.ws) * o) / 2;
      final dx = (p.dx - cx).abs();
      if (dx <= half && (p.dy - g.cy).abs() <= g.h / 2 + 20) {
        if (dx < bestDist) {
          bestDist = dx;
          best = v;
        }
      }
    }
    return best;
  }

  // ---- pointer ------------------------------------------------------------

  void _hoverAt(_Geo g, Offset p) {
    final v = _tapeAt(g, p);
    final over = v ?? -1;
    if (over != _hover) {
      _hover = over;
      if (over >= 0 && _rel(over).abs() > 0.5) _lift.putIfAbsent(over, () => 0);
    }
    final onCover =
        (p.dx - g.width / 2).abs() < 0.55 * g.d &&
        (p.dy - g.cy).abs() < 0.55 * g.h &&
        (_t - _s).abs() < 0.3;
    if (onCover) {
      _tiltYTarget = (p.dx - g.width / 2) / (0.55 * g.d) * 9;
      _tiltXTarget = -(p.dy - g.cy) / (g.h / 2) * 6;
    } else {
      _tiltYTarget = (p.dx - g.width / 2) / g.width * 5;
      _tiltXTarget = 0;
    }
    _kick();
  }

  void _onSignal(PointerSignalEvent e, _Geo g) {
    if (e is! PointerScrollEvent) return;
    final delta = e.scrollDelta.dx.abs() > e.scrollDelta.dy.abs()
        ? e.scrollDelta.dx
        : e.scrollDelta.dy;
    _t = _clampT(_t + delta / (g.ws + g.gap) * 0.5);
    _dir = delta >= 0 ? 1 : -1;
    _snapTimer?.cancel();
    _snapTimer = Timer(const Duration(milliseconds: 160), () {
      _t = _clampT(_t.roundToDouble());
      _kick();
    });
    _kick();
  }

  // ---- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(playQueueProvider).value ?? const <MediaItem>[];
    final index = ref.watch(
      playbackStateProvider.select((s) => s.value?.queueIndex),
    );
    final current = ref.watch(currentMediaItemProvider).value;
    final playing = ref.watch(playbackPlayingProvider);

    var cur = index ?? -1;
    if (current != null &&
        (cur < 0 || cur >= queue.length || queue[cur].id != current.id)) {
      cur = queue.indexWhere((m) => m.id == current.id);
    }
    final changedQueue = queue.length != _items.length;
    _items = queue;
    if (queue.isEmpty) return SizedBox(height: widget.height);
    if (!_initialised) {
      _initialised = true;
      _current = cur;
      final start = cur < 0 ? 0 : cur;
      _s = _t = start.toDouble();
    } else if (cur != _current) {
      _current = cur;
      if (cur >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _recenter(cur);
        });
      }
    } else if (changedQueue) {
      _recenter(math.max(0, cur));
    }

    final focusedIndex = _mod(_s.round(), _n);
    if (focusedIndex != _focused) {
      _focused = focusedIndex;
    }
    final focusedItem = queue[focusedIndex];
    final focusedIsCurrent = focusedIndex == _current;

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final g = _geo(constraints.maxWidth);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _FlarePainter(cx: g.width / 2, cy: g.cy, h: g.h),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Listener(
                  onPointerHover: (e) => _hoverAt(g, e.localPosition),
                  onPointerDown: (e) {
                    _dragging = true;
                    _dragMoved = false;
                    _dragStartX = e.localPosition.dx;
                    _dragT0 = _t;
                  },
                  onPointerMove: (e) {
                    if (!_dragging) return;
                    final dx = e.localPosition.dx - _dragStartX;
                    if (!_dragMoved && dx.abs() > 5) _dragMoved = true;
                    if (_dragMoved) {
                      _t = _clampT(_dragT0 - dx / (g.ws + g.gap));
                      _dir = dx < 0 ? 1 : -1;
                      _kick();
                    }
                  },
                  onPointerUp: (e) {
                    final moved = _dragMoved;
                    _dragging = false;
                    _dragMoved = false;
                    if (moved) {
                      _t = _clampT(_t.roundToDouble());
                      _kick();
                    } else {
                      final v = _tapeAt(g, e.localPosition);
                      if (v != null) _activate(v);
                    }
                  },
                  onPointerSignal: (e) => _onSignal(e, g),
                  child: MouseRegion(
                    cursor: _hover >= 0
                        ? SystemMouseCursors.click
                        : SystemMouseCursors.basic,
                    onExit: (_) {
                      _hover = -1;
                      _tiltXTarget = 0;
                      _tiltYTarget = 0;
                      _kick();
                    },
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..setEntry(3, 2, -1 / 2200),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: _tapes(
                          g,
                          queue,
                          focusedIndex,
                          playing && focusedIsCurrent,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 20,
                top: 12,
                child: DexRackChip(
                  icon: Icons.keyboard_arrow_down,
                  label: 'Hide records',
                  onTap: () => dexRackHidden.value = true,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 6,
                height: 54,
                child: _Caption(
                  item: focusedItem,
                  dir: _dir,
                  playing: playing && focusedIsCurrent,
                  onPrev: () => _moveTarget((_t - 1).roundToDouble()),
                  onNext: () => _moveTarget((_t + 1).roundToDouble()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _tapes(
    _Geo g,
    List<MediaItem> queue,
    int focused,
    bool spinning,
  ) {
    final total = _n * _copies;
    final entries = <({int v, double r})>[];
    for (var v = 0; v < total; v++) {
      final r = _rel(v);
      final x = _tapeX(g, r);
      if (x.abs() > g.width / 2 + 1.5 * g.d) continue;
      entries.add((v: v, r: r));
    }
    // Nearest on top.
    entries.sort((a, b) => b.r.abs().compareTo(a.r.abs()));
    return [for (final e in entries) _tape(g, queue, e.v, e.r, spinning)];
  }

  Widget _tape(_Geo g, List<MediaItem> queue, int v, double r, bool spinning) {
    final item = queue[_mod(v, _n)];
    final o = _smooth(math.max(0, 1 - r.abs()));
    final lift = _lift[v] ?? 0;
    const rad = math.pi / 180;
    final side = r == 0 ? 0.0 : r.sign;
    // Closed discs fan toward the centre like cover flow; the focused one
    // turns to face front, tilted a little and enlarged.
    final yaw = (-side * 68 * (1 - o) - 32 * o) * rad + _tiltY * o * rad;
    final pitch = _tiltX * o * rad;
    final roll = -22 * o * rad;
    final scale = 1 + 0.38 * o;
    final x = _tapeX(g, r);
    final matrix = Matrix4.identity()
      ..translateByDouble(
        g.width / 2 + x,
        g.cy - o * 0.30 * g.h - lift * 0.06 * g.h,
        o * 0.2 * g.h,
        1,
      )
      ..rotateZ(roll)
      ..rotateX(pitch)
      ..rotateY(yaw)
      ..multiply(Matrix4.diagonal3Values(scale, scale, 1));
    final cover = item.artUri?.toString();
    return Positioned(
      left: 0,
      top: 0,
      child: Transform(
        transform: matrix,
        child: SizedBox(
          width: 0,
          height: 0,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -g.h / 2,
                top: -g.h / 2,
                width: g.h,
                height: g.h,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DexRecordDisc(
                      size: g.h,
                      spinning: spinning && o > 0.5,
                      coverUrl: cover,
                    ),
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color.fromRGBO(0, 0, 0, (1 - o) * 0.45),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Geo {
  _Geo({required this.width, required this.h, required this.cy})
    : ws = h * 0.42,
      d = h * 1.45,
      gap = h * 0.05;

  final double width;
  final double h;
  final double cy;
  final double ws;
  final double d;
  final double gap;
}

/// Soft white bloom behind the focused disc with a faint spectrum streak
/// either side of it, like the reference photo.
class _FlarePainter extends CustomPainter {
  const _FlarePainter({required this.cx, required this.cy, required this.h});

  final double cx;
  final double cy;
  final double h;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(cx, cy - h * 0.30);
    canvas.drawCircle(
      c,
      h * 0.95,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x40FFFFFF), Color(0x00FFFFFF)],
        ).createShader(Rect.fromCircle(center: c, radius: h * 0.95)),
    );
    final streak = Rect.fromCenter(center: c, width: h * 3.2, height: 6);
    canvas.drawRect(
      streak,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..shader = const LinearGradient(
          colors: [
            Color(0x00FFFFFF),
            Color(0x55FF7AA8),
            Color(0x4478E8A0),
            Color(0x55FFFFFF),
            Color(0x4478C8FF),
            Color(0x55C890FF),
            Color(0x00FFFFFF),
          ],
        ).createShader(streak),
    );
  }

  @override
  bool shouldRepaint(_FlarePainter old) =>
      old.cx != cx || old.cy != cy || old.h != h;
}

/// Title, artist and album slide up through a mask when the focused record
/// changes, with arrows to either side.
class _Caption extends StatelessWidget {
  const _Caption({
    required this.item,
    required this.dir,
    required this.playing,
    required this.onPrev,
    required this.onNext,
  });

  final MediaItem item;
  final int dir;
  final bool playing;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  Widget _slide(String key, Widget child) => ClipRect(
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 650),
      switchInCurve: const Cubic(0.2, 0.8, 0.2, 1),
      switchOutCurve: const Cubic(0.2, 0.8, 0.2, 1),
      transitionBuilder: (child, animation) => SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, 1.05 * dir),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
      layoutBuilder: (current, previous) =>
          Stack(alignment: Alignment.center, children: [...previous, ?current]),
      child: KeyedSubtree(key: ValueKey('$key-${item.id}'), child: child),
    ),
  );

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _Arrow(icon: Icons.chevron_left, onTap: onPrev),
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 24,
              child: _slide(
                't',
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: _bone,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 18,
              child: _slide(
                'a',
                Text(
                  [item.artist, item.album]
                      .whereType<String>()
                      .where((s) => s.isNotEmpty)
                      .join('  /  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.6,
                    color: _muted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      _Arrow(icon: Icons.chevron_right, onTap: onNext),
    ],
  );
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Material(
      color: const Color(0xFF2E2E31),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 38,
          child: Icon(icon, size: 22, color: _bone),
        ),
      ),
    ),
  );
}

// Keep the ink constant referenced for future label chips.
// ignore: unused_element
const _unused = _ink;

/// A small pill button used to hide and show the rack.
class DexRackChip extends StatelessWidget {
  const DexRackChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF2E2E31),
    shape: const StadiumBorder(),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: _bone),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w600,
                color: _bone,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
