import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mornye/controllers/player_metadata_controller.dart';
import 'package:mornye/providers/music_player_provider.dart';
import 'package:mornye/utils/playback_seek_preview.dart';
import 'package:mornye/utils/string_utils.dart';
import 'package:mornye/widgets/cached_cover_image.dart';
import 'package:mornye/widgets/desktop/desktop_downloads_button.dart';
import 'package:mornye/widgets/desktop/desktop_inspector.dart';
import 'package:mornye/widgets/desktop/desktop_player_bar.dart'
    show toggleDesktopMiniPlayer;
import 'package:mornye/widgets/desktop/desktop_window.dart'
    show desktopMiniPlayerSupported;
import 'package:mornye/widgets/desktop/dex_shell_frame.dart';
import 'package:mornye/widgets/playback_seek_slider.dart';
import 'package:mornye/widgets/player_lyrics_section.dart';
import 'package:mornye/widgets/player_volume_control.dart';

const _bone = Color(0xFFF2F2F2);
const _ink = Color(0xFF0A0A0A);
const _muted = Color(0xFF9A9A9E);
const _chip = Color(0xFF2E2E31);

/// Window width from which the card sits beside the page.
const double dexNowPlayingCardBreakpoint = 1100;

const double _cardWidth = 300;

/// The tall now-playing card on the right of the Dex frame: cover, title,
/// progress and transport under a notched top edge. Takes no space while
/// nothing is loaded.
class DexNowPlayingSlot extends ConsumerWidget {
  const DexNowPlayingSlot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(currentMediaItemProvider).value;
    if (item == null) return const SizedBox.shrink();
    final m = DexPanelScope.maybeOf(context);
    // Sized from the wireframe's ratios of the glass panel; the page area
    // above already starts [DexPanelMetrics.contentTop] below the panel top.
    final top = m == null ? 8.0 : (m.cardTop - m.contentTop).clamp(0.0, 400.0);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        4,
        top,
        m?.cardRightInset ?? 16,
        m?.cardBottomInset ?? 16,
      ),
      child: SizedBox(
        width: m?.cardWidth ?? _cardWidth,
        child: DexNowPlayingCard(item: item),
      ),
    );
  }
}

class DexNowPlayingCard extends ConsumerStatefulWidget {
  const DexNowPlayingCard({super.key, required this.item});

  final MediaItem item;

  @override
  ConsumerState<DexNowPlayingCard> createState() => _DexNowPlayingCardState();
}

class _DexNowPlayingCardState extends ConsumerState<DexNowPlayingCard> {
  bool _lyrics = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final art = item.artUri?.toString();
    return CustomPaint(
      painter: const _NotchedCardPainter(),
      child: ClipPath(
        clipper: const _NotchClipper(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 54,
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 14),
                      child: Text(
                        'NOW PLAYING',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w700,
                          color: _muted,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _RoundChip(
                      icon: Icons.lyrics_outlined,
                      tooltip: 'Lyrics',
                      selected: _lyrics,
                      onTap: () => setState(() => _lyrics = !_lyrics),
                    ),
                    const SizedBox(width: 8),
                    _RoundChip(
                      icon: Icons.queue_music,
                      tooltip: 'Up next',
                      onTap: () =>
                          toggleDesktopInspector(DesktopInspectorPanel.upNext),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: _lyrics
                    ? const ClipRect(child: _CardLyrics())
                    : Center(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: art == null
                                ? const ColoredBox(
                                    color: _chip,
                                    child: Icon(
                                      Icons.music_note,
                                      color: _muted,
                                      size: 48,
                                    ),
                                  )
                                : CachedCoverImage(
                                    imageUrl: art,
                                    memCacheWidth: 600,
                                  ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: _bone,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.artist ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: _muted),
              ),
              const Expanded(flex: 2, child: _LyricsBand()),
              _Progress(item: item),
              const SizedBox(height: 10),
              const _TransportRow(),
              const SizedBox(height: 10),
              const _UtilityRow(),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundChip extends StatelessWidget {
  const _RoundChip({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: selected ? _bone : _chip,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 34,
          child: Icon(icon, size: 17, color: selected ? _ink : _bone),
        ),
      ),
    ),
  );
}

class _Progress extends ConsumerWidget {
  const _Progress({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duration = item.duration ?? Duration.zero;
    final position = ref.watch(playbackPositionProvider);
    final playing =
        ref.watch(playbackPlayingProvider) &&
        !ref.watch(playbackLoadingProvider);
    final elapsed = position.inSeconds.clamp(0, duration.inSeconds);
    const timeStyle = TextStyle(
      fontSize: 11,
      color: _muted,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          SizedBox(
            height: 22,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: _bone,
                inactiveTrackColor: const Color(0x2EFFFFFF),
                thumbColor: _bone,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              ),
              child: PlaybackSeekSlider(
                key: ValueKey(item.id),
                position: position,
                duration: duration,
                playing: playing,
                onSeek: ref.read(musicPlayerControllerProvider).seek,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatClock(elapsed), style: timeStyle),
              Text(formatClock(duration.inSeconds), style: timeStyle),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransportRow extends ConsumerWidget {
  const _TransportRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(musicPlayerControllerProvider);
    final playing = ref.watch(playbackPlayingProvider);
    final loading = ref.watch(playbackLoadingProvider);
    final shuffle = ref.watch(
      playbackStateProvider.select(
        (s) => s.value?.shuffleMode == AudioServiceShuffleMode.all,
      ),
    );
    final repeat = ref.watch(
      playbackStateProvider.select(
        (s) => s.value?.repeatMode ?? AudioServiceRepeatMode.none,
      ),
    );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _SquareButton(
            icon: Icons.shuffle,
            selected: shuffle,
            onTap: () => controller.setShuffle(!shuffle),
          ),
          _SquareButton(icon: Icons.skip_previous, onTap: controller.previous),
          Material(
            color: _bone,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: loading ? null : () => controller.togglePlayPause(playing),
              child: SizedBox.square(
                dimension: 58,
                child: loading
                    ? const Padding(
                        padding: EdgeInsets.all(18),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: _ink,
                        ),
                      )
                    : Icon(
                        playing ? Icons.pause : Icons.play_arrow,
                        size: 30,
                        color: _ink,
                      ),
              ),
            ),
          ),
          _SquareButton(icon: Icons.skip_next, onTap: controller.next),
          _SquareButton(
            icon: repeat == AudioServiceRepeatMode.one
                ? Icons.repeat_one
                : Icons.repeat,
            selected: repeat != AudioServiceRepeatMode.none,
            onTap: () => controller.setRepeatMode(switch (repeat) {
              AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
              AudioServiceRepeatMode.all => AudioServiceRepeatMode.one,
              _ => AudioServiceRepeatMode.none,
            }),
          ),
        ],
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({
    required this.icon,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? _bone : _chip,
    borderRadius: BorderRadius.circular(11),
    child: InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: onTap,
      child: SizedBox.square(
        dimension: 36,
        child: Icon(icon, size: 18, color: selected ? _ink : _bone),
      ),
    ),
  );
}

/// The card outline: a rounded rectangle whose top edge dips into a notch
/// at the leading side.
Path _notchedPath(Size size) {
  const r = 28.0;
  const notchStart = 124.0;
  const notchEnd = 214.0;
  const depth = 12.0;
  const curve = 14.0;
  final w = size.width;
  final h = size.height;
  return Path()
    ..moveTo(0, r)
    ..quadraticBezierTo(0, 0, r, 0)
    ..lineTo(notchStart, 0)
    ..cubicTo(
      notchStart + curve,
      0,
      notchStart + curve * 0.4,
      depth,
      notchStart + curve * 1.6,
      depth,
    )
    ..lineTo(notchEnd - curve * 1.6, depth)
    ..cubicTo(notchEnd - curve * 0.4, depth, notchEnd - curve, 0, notchEnd, 0)
    ..lineTo(w - r, 0)
    ..quadraticBezierTo(w, 0, w, r)
    ..lineTo(w, h - r)
    ..quadraticBezierTo(w, h, w - r, h)
    ..lineTo(r, h)
    ..quadraticBezierTo(0, h, 0, h - r)
    ..close();
}

class _NotchClipper extends CustomClipper<Path> {
  const _NotchClipper();

  @override
  Path getClip(Size size) => _notchedPath(size);

  @override
  bool shouldReclip(_NotchClipper oldClipper) => false;
}

class _NotchedCardPainter extends CustomPainter {
  const _NotchedCardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = _notchedPath(size);
    canvas.drawShadow(path, const Color(0xFF000000), 18, true);
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF232326), Color(0xFF18181A)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x1FFFFFFF),
    );
  }

  @override
  bool shouldRepaint(_NotchedCardPainter oldDelegate) => false;
}

/// Volume, mini player and downloads: what the docked bar used to carry.
class _UtilityRow extends StatelessWidget {
  const _UtilityRow();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(child: PlayerVolumeControl(foreground: _bone)),
      if (desktopMiniPlayerSupported)
        _RoundChip(
          icon: Icons.picture_in_picture_alt_outlined,
          tooltip: 'Mini player',
          onTap: () => unawaited(toggleDesktopMiniPlayer()),
        ),
      const SizedBox(width: 6),
      const DesktopDownloadsButton(),
    ],
  );
}

/// The live lyrics, in the space the cover normally fills.
class _CardLyrics extends ConsumerStatefulWidget {
  const _CardLyrics();

  @override
  ConsumerState<_CardLyrics> createState() => _CardLyricsState();
}

class _CardLyricsState extends ConsumerState<_CardLyrics> {
  final _metadata = PlayerMetadataController();
  final _seekPreview = PlaybackSeekPreview();
  ProviderSubscription<AsyncValue<MediaItem?>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.listenManual<AsyncValue<MediaItem?>>(currentMediaItemProvider, (
      previous,
      next,
    ) {
      if (previous?.value?.id == next.value?.id) return;
      unawaited(_metadata.load(next.value, inspectUnresolvedContentUri: true));
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _sub?.close();
    _metadata.dispose();
    _seekPreview.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PlayerLyricsSection(
    metadata: _metadata,
    seekPreview: _seekPreview,
    colorScheme: Theme.of(context).colorScheme,
    isActive: true,
  );
}

/// The live lyrics in the gap between the artist and the progress bar. The
/// view scrolls to the current line; its edges fade out. It hides itself when
/// the card is too short to show a line.
class _LyricsBand extends StatelessWidget {
  const _LyricsBand();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxHeight < 64) return const SizedBox.shrink();
      return ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x00FFFFFF),
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: [0.0, 0.18, 0.82, 1.0],
        ).createShader(rect),
        child: const ClipRect(child: _CardLyrics()),
      );
    },
  );
}
