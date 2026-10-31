import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static bool _loaded = false;

  /// Reads the saved level once. Safe to call repeatedly.
  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_key);
      for (final value in DexArtworkLevel.values) {
        if (value.name == saved) level.value = value;
      }
    } catch (_) {
      // Keep the default when preferences are unavailable.
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
        return IgnorePointer(
          child: ExcludeSemantics(
            child: RepaintBoundary(
              child: Opacity(
                opacity: (opacity * strength).clamp(0.0, 1.0),
                child: image,
              ),
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
      child: DexOrnament(
        DexArtwork.grungeStars,
        fit: BoxFit.cover,
        opacity: 0.07,
        minLevel: DexArtworkLevel.subtle,
      ),
    );
  }
}
