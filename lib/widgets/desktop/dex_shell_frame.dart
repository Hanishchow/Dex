import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:mornye/services/shell_navigation_service.dart';
import 'package:mornye/theme/dex_gothic.dart';
import 'package:mornye/widgets/desktop/desktop_navigation.dart';

/// Whether desktop windows use the floating glass frame (scene, rounded
/// panel, pill navigation and icon rail) instead of the sidebar layouts.
const bool dexFloatingFrame = true;

const _bone = Color(0xFFF2F2F2);
const _ink = Color(0xFF0A0A0A);

/// The Dex desktop frame: a charcoal scene with a light beam, one large
/// rounded glass panel holding the icon rail and the page, a pill navigation
/// that overlaps the panel's top edge, and the player underneath.
///
/// Works with both theme styles, so it only reads plain colors.
class DexShellFrame extends StatelessWidget {
  const DexShellFrame({
    super.key,
    required this.destinations,
    required this.selected,
    required this.onSelected,
    required this.content,
    this.playerBar,
  });

  final List<DesktopDestination> destinations;
  final ShellTab? selected;
  final ValueChanged<ShellTab> onSelected;

  /// The page area (and inspector) laid out inside the panel.
  final Widget content;

  /// A docked player below the panel; null when the player floats inside it.
  final Widget? playerBar;

  @override
  Widget build(BuildContext context) {
    final player = playerBar;
    return ColoredBox(
      color: const Color(0xFF080809),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: RepaintBoundary(child: CustomPaint(painter: _ScenePainter())),
          ),
          Column(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 44, 20, player == null ? 20 : 8),
                  child: _GlassPanel(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _IconRail(
                          destinations: destinations,
                          selected: selected,
                          onSelected: onSelected,
                        ),
                        // The pill overlaps the panel's top edge, so pages
                        // start below it.
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: content,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ?player,
            ],
          ),
          Positioned(
            top: 14,
            left: 0,
            right: 0,
            child: Center(
              child: _TopNav(
                destinations: destinations,
                selected: selected,
                onSelected: onSelected,
              ),
            ),
          ),
          const Positioned(top: 18, left: 36, child: _TitlePill()),
        ],
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  const _ScenePainter();

  @override
  void paint(Canvas canvas, Size size) {
    // A soft diagonal beam falling from the top right.
    final beam = Path()
      ..moveTo(size.width * 0.55, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.55)
      ..close();
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0x40FFFFFF), Color(0x00FFFFFF)],
      ).createShader(Offset.zero & size)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 70);
    canvas.drawPath(beam, paint);
  }

  @override
  bool shouldRepaint(_ScenePainter oldDelegate) => false;
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(30),
      boxShadow: const [
        BoxShadow(color: Color(0x99000000), blurRadius: 40, offset: Offset(0, 16)),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1F1F21), Color(0xFF141415)],
          ),
          border: Border.all(color: const Color(0x1FFFFFFF)),
        ),
        child: child,
      ),
    ),
  );
}

class _TitlePill extends StatelessWidget {
  const _TitlePill();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFF262628),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0x1FFFFFFF)),
    ),
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(
        'Dex',
        style: TextStyle(
          fontFamily: dexBlackletterFont,
          fontSize: 24,
          height: 1.1,
          color: _bone,
        ),
      ),
    ),
  );
}

class _TopNav extends StatelessWidget {
  const _TopNav({
    required this.destinations,
    required this.selected,
    required this.onSelected,
  });

  final List<DesktopDestination> destinations;
  final ShellTab? selected;
  final ValueChanged<ShellTab> onSelected;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(999),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xCC2A2A2C),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x26FFFFFF)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final destination in destinations)
                _NavTab(
                  key: ValueKey('dex-nav-${destination.tab.name}'),
                  label: destination.label,
                  selected: destination.tab == selected,
                  onTap: () => onSelected(destination.tab),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? _bone : Colors.transparent,
    shape: const StadiumBorder(),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: selected ? _ink : const Color(0xFFCFCFCF),
          ),
        ),
      ),
    ),
  );
}

class _IconRail extends StatelessWidget {
  const _IconRail({
    required this.destinations,
    required this.selected,
    required this.onSelected,
  });

  final List<DesktopDestination> destinations;
  final ShellTab? selected;
  final ValueChanged<ShellTab> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 28, 4, 16),
    child: Align(
      alignment: Alignment.topCenter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF232325),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0x1AFFFFFF)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final destination in destinations)
                _RailButton(
                  key: ValueKey('dex-rail-${destination.tab.name}'),
                  destination: destination,
                  selected: destination.tab == selected,
                  onTap: () => onSelected(destination.tab),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    super.key,
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final DesktopDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Tooltip(
      message: destination.label,
      child: Material(
        color: selected ? _bone : const Color(0xFF38383A),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 42,
            child: Icon(
              selected ? destination.selectedIcon : destination.icon,
              size: 20,
              color: selected ? _ink : const Color(0xFFD8D8D8),
            ),
          ),
        ),
      ),
    ),
  );
}
