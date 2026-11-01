import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dex_motion_field.dart';

/// The gothic artwork shipped in `assets/gothic/`. Every asset is white with
/// an alpha channel (see `tools/gothic_assets.py`) and is tinted at paint time
/// so one file serves both themes.
enum DexArtwork {
  sword('sword'),
  halftoneStar('halftone_star'),
  binaryStars('binary_stars'),
  script('script'),
  cornerFiligree('corner_filigree'),
  crossCrescent('cross_crescent'),
  thornCrescent('thorn_crescent'),
  glowCrosses('glow_crosses'),
  grungeStars('grunge_stars'),
  halftoneClouds('halftone_clouds'),
  figure('figure'),
  lilyChandelier('lily_chandelier');

  const DexArtwork(this._name);
  final String _name;
  String get asset => 'assets/gothic/$_name.png';
}

/// How much artwork the interface shows.
enum DexArtworkLevel { off, subtle, heavy }

/// The user's artwork level, shared by every [DexOrnament].
abstract final class DexArt {
  static const _key = 'dex_artwork_level';

  static final ValueNotifier<DexArtworkLevel> level = ValueNotifier(
    DexArtworkLevel.heavy,
  );

  static const _startupKey = 'dex_startup_animation';

  /// Whether the startup animation plays at launch.
  static final ValueNotifier<bool> startupAnimation = ValueNotifier(true);

  static bool _loaded = false;

  /// Reads the saved settings once. Safe to call repeatedly.
  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      for (final value in DexArtworkLevel.values) {
        if (value.name == saved) level.value = value;
      }
      startupAnimation.value = prefs.getBool(_startupKey) ?? true;
    } catch (_) {
      // Keep the defaults when preferences are unavailable.
    }
  }

  static Future<void> setStartupAnimation(bool value) async {
    startupAnimation.value = value;
    try {
      await (await SharedPreferences.getInstance()).setBool(_startupKey, value);
    } catch (_) {
      // The choice still applies for this session.
    }
  }

  static Future<void> set(DexArtworkLevel value) async {
    level.value = value;
    try {
      await (await SharedPreferences.getInstance()).setString(_key, value.name);
    } catch (_) {
      // The choice still applies for this session.
    }
  }
}

/// One piece of gothic artwork, tinted to the theme (bone on dark, ink on
/// light), non-interactive and cached as its own layer.
///
/// [minLevel] hides decorative extras when the user picks a quieter level;
/// [opacity] is the strength at the heavy level and is reduced at subtle.
class DexOrnament extends StatelessWidget {
  const DexOrnament(
    this.art, {
    super.key,
    this.width,
    this.height,
    this.opacity = 0.14,
    this.alignment = Alignment.center,
    this.fit = BoxFit.contain,
    this.flipX = false,
    this.flipY = false,
    this.minLevel = DexArtworkLevel.subtle,
    this.depth = 0,
    this.breathe = 0,
    this.sway = 0,
    this.shimmer = false,
    this.energyAware = false,
    this.phase = 0,
  });

  final DexArtwork art;
  final double? width;
  final double? height;
  final double opacity;
  final Alignment alignment;
  final BoxFit fit;
  final bool flipX;
  final bool flipY;
  final DexArtworkLevel minLevel;

  /// Parallax in pixels: how far the piece follows the mouse at the window
  /// edge. Larger values read as nearer to the viewer.
  final double depth;

  /// 0..1: how strongly it breathes (a slow swell in size and brightness).
  final double breathe;

  /// Radians of slow rocking.
  final double sway;

  /// A pale band of light crosses the piece every few seconds.
  final bool shimmer;

  /// Breathes faster and deeper while music plays, and rests when paused.
  final bool energyAware;

  /// 0..1 offset so neighbouring pieces do not move in step.
  final double phase;

  bool get _animated => depth > 0 || breathe > 0 || sway > 0 || shimmer;

  static const _shimmerEvery = 11.0;
  static const _shimmerFor = 2.4;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DexArtworkLevel>(
      valueListenable: DexArt.level,
      builder: (context, level, _) {
        if (level == DexArtworkLevel.off || level.index < minLevel.index) {
          return const SizedBox.shrink();
        }
        final dark = Theme.of(context).brightness == Brightness.dark;
        final tint = dark ? const Color(0xFFEFE6DD) : const Color(0xFF0A0A0A);
        final strength = level == DexArtworkLevel.subtle ? 0.6 : 1.0;
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final reduce = MediaQuery.disableAnimationsOf(context);
        Widget image = Image.asset(
          art.asset,
          width: width,
          height: height,
          fit: fit,
          alignment: alignment,
          color: tint,
          colorBlendMode: BlendMode.srcIn,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          cacheWidth: width != null ? (width! * dpr).ceil() : null,
        );
        if (flipX || flipY) {
          image = Transform.scale(
            scaleX: flipX ? -1 : 1,
            scaleY: flipY ? -1 : 1,
            child: image,
          );
        }
        final base = (opacity * strength).clamp(0.0, 1.0);
        if (!_animated || reduce) {
          return IgnorePointer(
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: Opacity(opacity: base, child: image),
              ),
            ),
          );
        }
        // The image is built once and shared by every frame; only the
        // transform and opacity layers change, so nothing is re-rasterised.
        final still = RepaintBoundary(child: image);
        final period = energyAware ? 7.0 : 9.0;
        return IgnorePointer(
          child: ExcludeSemantics(
            child: ListenableBuilder(
              listenable: DexMotionField.frame,
              builder: (context, _) {
                final t = DexMotionField.time + phase * period;
                final k = level == DexArtworkLevel.subtle ? 0.5 : 1.0;
                final e = energyAware ? 0.2 + 0.8 * DexMotionField.energy : 1.0;
                final speed = energyAware
                    ? 1 + 0.9 * DexMotionField.energy
                    : 1.0;
                final wave = math.sin(t * speed * 2 * math.pi / period);
                final p = DexMotionField.pointer;
                final scale = 1 + breathe * k * e * 0.04 * wave;
                final angle =
                    sway * k * math.sin(t * 2 * math.pi / (period * 1.7) + 1.3);
                final o = (base * (1 + breathe * k * e * 0.4 * wave)).clamp(
                  0.0,
                  1.0,
                );
                Widget content = still;
                // A band of light sweeps across for a moment now and then.
                if (shimmer) {
                  final u = ((t + phase * 5) % _shimmerEvery) / _shimmerFor;
                  if (u >= 0 && u < 1) {
                    final c = -0.25 + 1.5 * u;
                    content = Stack(
                      fit: StackFit.passthrough,
                      children: [
                        still,
                        ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (rect) => LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: const [
                              Color(0x00FFFFFF),
                              Color(0xFFFFFFFF),
                              Color(0x00FFFFFF),
                            ],
                            stops: [
                              (c - 0.14).clamp(0.0, 1.0),
                              c.clamp(0.0, 1.0),
                              (c + 0.14).clamp(0.0, 1.0),
                            ],
                          ).createShader(rect),
                          child: Opacity(opacity: 0.9, child: still),
                        ),
                      ],
                    );
                  }
                }
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..translateByDouble(
                      p.dx * depth * k,
                      p.dy * depth * k,
                      0,
                      1,
                    )
                    ..rotateZ(angle)
                    ..scaleByDouble(scale, scale, 1, 1),
                  child: Opacity(opacity: o, child: content),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// A full-window grunge-star texture, drawn faintly over the whole app. It
/// reads the saved artwork level the first time it is built.
class DexGothicBackdrop extends StatefulWidget {
  const DexGothicBackdrop({super.key});

  @override
  State<DexGothicBackdrop> createState() => _DexGothicBackdropState();
}

class _DexGothicBackdropState extends State<DexGothicBackdrop> {
  @override
  void initState() {
    super.initState();
    DexArt.load();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The texture stays still: moving a full-window image every tick costs far\n          // more than every other ornament together. Embers and the smaller\n          // pieces carry the motion.
          DexOrnament(
            DexArtwork.grungeStars,
            fit: BoxFit.cover,
            opacity: 0.11,
            minLevel: DexArtworkLevel.subtle,
          ),
          DexEmberField(),
        ],
      ),
    );
  }
}

/// A halftone star that turns slowly: the loading indicator on desktop when
/// artwork is on. It stands still under reduced motion.
class DexStarSpinner extends StatefulWidget {
  const DexStarSpinner({super.key, this.size = 32});

  final double size;

  @override
  State<DexStarSpinner> createState() => _DexStarSpinnerState();
}

class _DexStarSpinnerState extends State<DexStarSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turns = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (animate) {
      if (!_turns.isAnimating) _turns.repeat();
    } else {
      _turns.stop();
    }
  }

  @override
  void dispose() {
    _turns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: SizedBox.square(
        dimension: widget.size,
        child: RotationTransition(
          turns: _turns,
          child: DexOrnament(
            DexArtwork.halftoneStar,
            width: widget.size,
            height: widget.size,
            opacity: 0.95,
          ),
        ),
      ),
    );
  }
}
