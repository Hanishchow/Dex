import 'package:flutter/material.dart';
import 'package:mornye/widgets/app_icon.dart';
import 'package:mornye/widgets/dex/dex_ornament.dart';
import 'package:mornye/widgets/settings_group.dart';

/// Appearance settings for Dex's gothic artwork: how much of it shows, and
/// whether the startup animation plays.
class DexGothicSettingsGroup extends StatelessWidget {
  const DexGothicSettingsGroup({super.key});

  static const _levels = <DexArtworkLevel, (String, String)>{
    DexArtworkLevel.off: ('Off', 'Plain black and white, no artwork'),
    DexArtworkLevel.subtle: ('Subtle', 'Faint corners and texture only'),
    DexArtworkLevel.heavy: ('Heavy', 'Full gothic artwork across the app'),
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<DexArtworkLevel>(
      valueListenable: DexArt.level,
      builder: (context, current, _) => SettingsGroup(
        children: [
          for (final entry in _levels.entries)
            ListTile(
              leading: const AppIcon(Icons.auto_awesome_outlined),
              title: Text(entry.value.$1),
              subtitle: Text(entry.value.$2),
              trailing: current == entry.key
                  ? AppIcon(Icons.check_circle, color: scheme.primary)
                  : null,
              selected: current == entry.key,
              onTap: () => DexArt.set(entry.key),
            ),
          ValueListenableBuilder<bool>(
            valueListenable: DexArt.startupAnimation,
            builder: (context, enabled, _) => SettingsSwitchItem(
              icon: Icons.movie_filter_outlined,
              title: 'Startup animation',
              subtitle: 'Play the DEX intro when the app opens',
              value: enabled,
              onChanged: DexArt.setStartupAnimation,
              showDivider: false,
            ),
          ),
        ],
      ),
    );
  }
}
