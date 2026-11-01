import 'package:flutter/material.dart';
import 'package:mornye/providers/explore_provider.dart';
import 'package:mornye/widgets/cached_cover_image.dart';
import 'package:mornye/utils/desktop_platform.dart';
import 'package:mornye/widgets/desktop/desktop_scroll_arrows.dart';
import 'package:mornye/widgets/dex/dex_ornament.dart';
import 'package:mornye/widgets/dex/dex_pressable.dart';
import 'package:mornye/widgets/audio_quality_badges.dart';

/// Large editorial cards requested by a home-feed provider.
class ExploreFeaturedSection extends StatelessWidget {
  final ExploreSection section;
  final void Function(ExploreItem, BuildContext) onItemTap;

  const ExploreFeaturedSection({
    super.key,
    required this.section,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Desktop windows show about three editorial cards across; phones and
        // narrow windows keep one large card.
        final wide = isDesktopPlatform && constraints.maxWidth >= 1000;
        final width = wide
            ? ((constraints.maxWidth - 48 - 24) / 3).clamp(320.0, 460.0)
            : (constraints.maxWidth - 48).clamp(160.0, 560.0);
        final imageHeight = width / 1.5;
        final headingHeight = scaler.scale(12) * 1.5;
        final titleHeight = scaler.scale(22) * 1.4;
        final artistHeight = scaler.scale(16) * 1.5;
        final descriptionHeight = scaler.scale(14) * 1.5 * 2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Text(
                section.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(
              height:
                  headingHeight +
                  titleHeight +
                  artistHeight +
                  imageHeight +
                  descriptionHeight +
                  24,
              child: DesktopScrollArrows(
                builder: (context, controller) => ListView.separated(
                  controller: controller,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: section.items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final item = section.items[index];
                    final image = item.featuredCoverUrl?.isNotEmpty == true
                        ? item.featuredCoverUrl
                        : item.coverUrl;
                    final fallback = ColoredBox(
                      color: colors.surfaceContainerHighest,
                      child: Center(
                        child: Icon(
                          Icons.album_outlined,
                          size: 48,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    );
                    return Builder(
                      builder: (itemContext) => DexPressable(
                        onTap: () => onItemTap(item, itemContext),
                        hoverArt: DexArtwork.cornerFiligree,
                        borderRadius: BorderRadius.circular(12),
                        semanticLabel: item.name,
                        child: SizedBox(
                          width: width,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: headingHeight,
                                child: Text(
                                  item.heading ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.5,
                                    fontWeight: FontWeight.w600,
                                    color: colors.primary,
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: titleHeight,
                                child: ExplicitTrackTitle(
                                  title: item.name,
                                  explicit: item.explicit == true,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: artistHeight,
                                child: Text(
                                  item.artists,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    height: 1.5,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: width,
                                  height: imageHeight,
                                  child: image == null || image.isEmpty
                                      ? fallback
                                      : CachedCoverImage(
                                          imageUrl: image,
                                          // Decode one axis so wide editorial art
                                          // keeps its ratio on high-density screens.
                                          memCacheWidth:
                                              (width *
                                                      MediaQuery.devicePixelRatioOf(
                                                        context,
                                                      ))
                                                  .ceil()
                                                  .clamp(320, 960),
                                          fit: BoxFit.cover,
                                          placeholder: (_, _) => fallback,
                                          errorWidget: (_, _, _) => fallback,
                                        ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.description ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
