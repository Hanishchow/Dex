import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mornye/providers/explore_provider.dart';
import 'package:mornye/utils/string_utils.dart';
import 'package:mornye/widgets/cached_cover_image.dart';
import 'package:mornye/widgets/dex/dex_pressable.dart';
import 'package:mornye/widgets/desktop/dex_shell_frame.dart';

const _bone = Color(0xFFF2F2F2);
const _ink = Color(0xFF0A0A0A);
const _muted = Color(0xFF9A9A9E);
const _chip = Color(0xFF2E2E31);

/// The top of Home in the Dex frame: three tilted cover cards fanned over
/// a round play button, above a short list of rows. Both draw from the
/// Explore feed. Hidden in narrow panes and while the feed is empty.
class DexHomeDeck extends StatelessWidget {
  const DexHomeDeck({
    super.key,
    required this.sections,
    required this.onItemTap,
  });

  final List<ExploreSection> sections;
  final void Function(ExploreItem item, BuildContext context) onItemTap;

  static bool _hasCover(ExploreItem item) =>
      item.coverUrl != null && item.coverUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final plain = sections.where((s) => !s.isFeatured).toList();
    final fanSection = plain.cast<ExploreSection?>().firstWhere(
      (s) => s!.items.where(_hasCover).length >= 3,
      orElse: () => null,
    );
    if (fanSection == null) return const SizedBox.shrink();
    final fan = fanSection.items.where(_hasCover).take(3).toList();
    final rowSection =
        plain.cast<ExploreSection?>().firstWhere(
          (s) =>
              s != fanSection && s!.isYTMusicQuickPicks && s.items.isNotEmpty,
          orElse: () => null,
        ) ??
        plain.cast<ExploreSection?>().firstWhere(
          (s) => s != fanSection && s!.items.length >= 3,
          orElse: () => null,
        );
    final rows = rowSection?.items.take(5).toList() ?? const <ExploreItem>[];
    final metrics = DexPanelScope.maybeOf(context);
    final fanHeight = metrics?.fanHeight ?? 250.0;
    final rowHeight = metrics?.rowHeight ?? 62.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CardFan(items: fan, onItemTap: onItemTap, fanHeight: fanHeight),
              const SizedBox(height: 12),
              for (var i = 0; i < rows.length; i++)
                DexTrackRow(
                  item: rows[i],
                  highlighted: i == 0,
                  height: rowHeight,
                  onTap: (ctx) => onItemTap(rows[i], ctx),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CardFan extends StatelessWidget {
  const _CardFan({
    required this.items,
    required this.onItemTap,
    required this.fanHeight,
  });

  final List<ExploreItem> items;
  final void Function(ExploreItem item, BuildContext context) onItemTap;

  double get _cardWidth => fanHeight * 0.70;
  double get _height => fanHeight;

  /// 37.7% of the panel height, from the wireframe.
  final double fanHeight;
  static const _tilts = [-0.07, 0.015, 0.10];
  static const _lifts = [14.0, 0.0, 18.0];

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _height,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final centre = constraints.maxWidth / 2;
        final spread = math.min(168.0, (constraints.maxWidth - _cardWidth) / 2);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < items.length; i++)
              Positioned(
                left: centre - _cardWidth / 2 + (i - 1) * spread,
                top: _lifts[i],
                width: _cardWidth,
                child: Transform.rotate(
                  angle: _tilts[i],
                  child: _FanCard(item: items[i], onItemTap: onItemTap),
                ),
              ),
            Positioned(
              left: centre - 32,
              top: _height / 2 - 28,
              child: Builder(
                builder: (ctx) => Material(
                  color: _bone,
                  shape: const CircleBorder(),
                  elevation: 6,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => onItemTap(items[1], ctx),
                    child: const SizedBox.square(
                      dimension: 64,
                      child: Icon(Icons.play_arrow, size: 34, color: _ink),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _FanCard extends StatelessWidget {
  const _FanCard({required this.item, required this.onItemTap});

  final ExploreItem item;
  final void Function(ExploreItem item, BuildContext context) onItemTap;

  @override
  Widget build(BuildContext context) => DexPressable(
    onTap: () => onItemTap(item, context),
    borderRadius: BorderRadius.circular(22),
    hoverFill: false,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF222225),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x1FFFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x88000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CachedCoverImage(
                      imageUrl: item.coverUrl!,
                      memCacheWidth: 400,
                    ),
                  ),
                ),
                const Positioned(
                  top: 8,
                  right: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xAA000000),
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(
                      dimension: 22,
                      child: Icon(Icons.more_horiz, size: 14, color: _bone),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _bone,
              ),
            ),
            Text(
              item.artists.isEmpty ? (item.heading ?? '') : item.artists,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: _muted),
            ),
            const SizedBox(height: 8),
            const _DashedLine(),
          ],
        ),
      ),
    ),
  );
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(double.infinity, 3),
    painter: _DashPainter(),
  );
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x40FFFFFF)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    for (var x = 0.0; x < size.width; x += 12) {
      canvas.drawLine(Offset(x, 1.5), Offset(x + 6, 1.5), paint);
    }
    final done = Paint()
      ..color = _bone
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    canvas.drawLine(const Offset(0, 1.5), Offset(size.width * 0.3, 1.5), done);
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => false;
}

/// One row: round cover, two text lines, duration, and two round buttons.
class DexTrackRow extends StatelessWidget {
  const DexTrackRow({
    super.key,
    required this.item,
    required this.onTap,
    this.highlighted = false,
    this.height = 62,
  });

  final double height;
  final ExploreItem item;
  final void Function(BuildContext context) onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final seconds = (item.durationMs / 1000).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: DexPressable(
        onTap: () => onTap(context),
        borderRadius: BorderRadius.circular(18),
        pressScale: false,
        hoverLift: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: highlighted ? const Color(0x14FFFFFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: SizedBox(
            height: height - 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  ClipOval(
                    child: SizedBox.square(
                      dimension: 46,
                      child: DexHomeDeck._hasCover(item)
                          ? CachedCoverImage(
                              imageUrl: item.coverUrl!,
                              memCacheWidth: 120,
                            )
                          : const ColoredBox(
                              color: _chip,
                              child: Icon(Icons.music_note, color: _muted),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _bone,
                          ),
                        ),
                        Text(
                          item.artists,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(
                      seconds > 0 ? formatClock(seconds) : '–',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _muted,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  _RoundAction(
                    icon: Icons.play_arrow,
                    onTap: () => onTap(context),
                  ),
                  const SizedBox(width: 8),
                  _RoundAction(
                    icon: Icons.more_horiz,
                    onTap: () => onTap(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: _chip,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox.square(
        dimension: 34,
        child: Icon(icon, size: 18, color: _bone),
      ),
    ),
  );
}
