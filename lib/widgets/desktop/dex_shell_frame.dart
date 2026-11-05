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
    const left = 40.0;
    const right = 20.0;
    const top = 46.0;
    final bottom = player == null ? 20.0 : 8.0;
    return ColoredBox(
      color: const Color(0xFF080809),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _ScenePainter()),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final panel = Size(
                      constraints.maxWidth - left - right,
                      constraints.maxHeight - top - bottom,
                    );
                    final m = DexPanelMetrics(size: panel);
                    final railHeight = m.railHeight(destinations.length);
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: left,
                          top: top,
                          width: panel.width,
                          height: panel.height,
                          child: _GlassPanel(
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: m.contentLeft,
                                top: m.contentTop,
                              ),
                              child: DexPanelScope(
                                metrics: m,
                                child: _glassTheme(context, content),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: left - m.railOutside,
                          top: top + (panel.height - railHeight) / 2,
                          width: m.railWidth,
                          height: railHeight,
                          child: _IconRail(
                            metrics: m,
                            destinations: destinations,
                            selected: selected,
                            onSelected: onSelected,
                          ),
                        ),
                        Positioned(
                          left: left + (panel.width - m.pillWidth) / 2,
                          top: top - m.pillHeight / 2,
                          width: m.pillWidth,
                          height: m.pillHeight,
                          child: _TopNav(
                            destinations: destinations,
                            selected: selected,
                            onSelected: onSelected,
                          ),
                        ),
                        Positioned(
                          left: left + panel.width * 0.026,
                          top: top + panel.height * 0.05,
                          child: const _TitlePill(),
                        ),
                      ],
                    );
                  },
                ),
              ),
              ?player,
            ],
          ),
        ],
      ),
    );
  }
}

/// Lets pages sit on the glass: their scaffold is clear and their surface
/// matches the panel's mid tone, so no flat black slab shows inside it.
Widget _glassTheme(BuildContext context, Widget child) {
  final theme = Theme.of(context);
  return Theme(
    data: theme.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: theme.colorScheme.copyWith(surface: const Color(0xFF19191B)),
    ),
    child: child,
  );
}

/// Proportions of the Dex frame, measured from the wireframe whose panel
/// is 457 x 326: every region is a fraction of the glass panel, so the
/// layout keeps its shape at any window size.
class DexPanelMetrics {
  const DexPanelMetrics({required this.size});

  final Size size;

  double get w => size.width;
  double get h => size.height;

  /// Pill navigation: half the panel wide, centred on the top edge.
  double get pillWidth => (w * 0.503).clamp(360.0, 760.0);
  double get pillHeight => 44;

  /// Icon rail: 9.2% of the panel height wide, straddling the left edge
  /// with 57% of its width outside the panel.
  double get railWidth => (h * 0.092).clamp(52.0, 68.0);
  double get railOutside => railWidth * 0.567;
  double get railPitch => (h * 0.09).clamp(50.0, 66.0);
  double railHeight(int count) => railPitch * (count - 1 + 1.56);

  /// The page starts after the rail's inside part and 2.4% of the width.
  double get contentLeft => railWidth * 0.433 + w * 0.024 + 8;
  double get contentTop => (h * 0.075).clamp(40.0, 60.0);

  /// Now-playing card: 14% down, 84% tall, 38% wide (never wider than
  /// 0.64 of its height), 1.3% from the right and 1.8% from the bottom.
  double get cardTop => h * 0.14;
  double get cardBottomInset => h * 0.018;
  double get cardRightInset => w * 0.013;
  double get cardHeight => h * (1 - 0.14 - 0.018);
  double get cardWidth => (w * 0.383).clamp(0.0, cardHeight * 0.639);

  /// Home deck: the fan is 37.7% of the height, rows 9% each.
  double get fanHeight => (h * 0.377).clamp(200.0, 320.0);
  double get rowHeight => (h * 0.0905).clamp(50.0, 68.0);
}

/// Hands [DexPanelMetrics] to everything laid out inside the panel.
class DexPanelScope extends InheritedWidget {
  const DexPanelScope({super.key, required this.metrics, required super.child});

  final DexPanelMetrics metrics;

  static DexPanelMetrics? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DexPanelScope>()?.metrics;

  @override
  bool updateShouldNotify(DexPanelScope oldWidget) =>
      oldWidget.metrics.size != metrics.size;
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
        BoxShadow(
          color: Color(0x99000000),
          blurRadius: 40,
          offset: Offset(0, 16),
        ),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final destination in destinations)
                Expanded(
                  child: _NavTab(
                    key: ValueKey('dex-nav-${destination.tab.name}'),
                    label: destination.label,
                    selected: destination.tab == selected,
                    onTap: () => onSelected(destination.tab),
                  ),
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
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.2,
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
    required this.metrics,
    required this.destinations,
    required this.selected,
    required this.onSelected,
  });

  final DexPanelMetrics metrics;
  final List<DesktopDestination> destinations;
  final ShellTab? selected;
  final ValueChanged<ShellTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final pitch = metrics.railPitch;
    // The wireframe's dots are half the pitch, with a floor so they stay
    // comfortable to click.
    final dot = (pitch * 0.5).clamp(34.0, 44.0);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF232325),
        borderRadius: BorderRadius.circular(metrics.railWidth / 2),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final destination in destinations)
            SizedBox(
              height: pitch,
              child: Center(
                child: _RailButton(
                  key: ValueKey('dex-rail-${destination.tab.name}'),
                  destination: destination,
                  selected: destination.tab == selected,
                  dimension: dot,
                  onTap: () => onSelected(destination.tab),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    super.key,
    required this.destination,
    required this.selected,
    required this.dimension,
    required this.onTap,
  });

  final DesktopDestination destination;
  final bool selected;
  final double dimension;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: destination.label,
    child: Material(
      color: selected ? _bone : const Color(0xFF38383A),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: dimension,
          child: Icon(
            selected ? destination.selectedIcon : destination.icon,
            size: dimension * 0.48,
            color: selected ? _ink : const Color(0xFFD8D8D8),
          ),
        ),
      ),
    ),
  );
}
