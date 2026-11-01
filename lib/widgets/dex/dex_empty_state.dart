import 'package:flutter/material.dart';

import 'package:mornye/theme/dex_gothic.dart';
import 'package:mornye/widgets/dex/dex_ornament.dart';

/// A small engraved lily, drawn in monospace. Used until the SVG emblem set
/// replaces it.
const String dexLilyEmblem = r'''
     .  |  .
   . \  |  / .
  -=< \ | / >=-
     '-\|/-'
       (|)
        |
       \|/''';

/// The shared empty state: emblem, Cinzel title, a hairline rule and a short
/// line of body text. Keep the text to one thought; pass [action] for the next
/// step.
class DexEmptyState extends StatelessWidget {
  const DexEmptyState({
    super.key,
    required this.title,
    this.message,
    this.action,
    this.emblem = dexLilyEmblem,
    this.art,
  });

  final String title;
  final String? message;
  final Widget? action;
  final String emblem;

  /// Gothic artwork shown instead of the ASCII [emblem] when the artwork
  /// level is on.
  final DexArtwork? art;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<DexArtworkLevel>(
                valueListenable: DexArt.level,
                builder: (context, level, _) {
                  if (art != null && level != DexArtworkLevel.off) {
                    return DexOrnament(
                      art!,
                      height: 220,
                      opacity: 0.7,
                      depth: 8,
                      breathe: 0.5,
                      sway: 0.02,
                    );
                  }
                  return ExcludeSemantics(
                    child: Text(
                      emblem,
                      style: TextStyle(
                        fontFamily: 'Consolas',
                        fontFamilyFallback: const [
                          'Cascadia Mono',
                          'monospace',
                        ],
                        fontSize: 15,
                        height: 1.15,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontFamily: dexHeadingFont,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 14),
              Container(height: 1, width: 56, color: scheme.outline),
              if (message != null) ...[
                const SizedBox(height: 14),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
              if (action != null) ...[const SizedBox(height: 24), action!],
            ],
          ),
        ),
      ),
    );
  }
}
