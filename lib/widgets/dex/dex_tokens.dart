import 'package:flutter/widgets.dart';

/// Motion tokens for Dex. Independent of the Material/Mornye theme styles, so
/// every screen can share the same durations and curves.
///
/// Rules: keyboard-initiated changes use [Duration.zero]; nothing at UI level
/// is slower than [panel]; exits are faster than enters; never ease-in.
abstract final class DexMotion {
  /// Press feedback on pointer-down.
  static const press = Duration(milliseconds: 110);

  /// Hover and focus changes.
  static const hover = Duration(milliseconds: 120);

  /// Menus, popovers, tooltips.
  static const popover = Duration(milliseconds: 180);

  /// Dialogs, side panels, page content.
  static const panel = Duration(milliseconds: 260);

  /// Faster exit for anything that entered over [popover] or [panel].
  static const exit = Duration(milliseconds: 150);

  /// Stagger step between list items, capped at [staggerMax] items.
  static const stagger = Duration(milliseconds: 40);
  static const staggerMax = 8;

  /// Strong ease-out for enters and responses.
  static const Curve out = Cubic(0.23, 1, 0.32, 1);

  /// Ease-in-out for things moving across the screen.
  static const Curve move = Cubic(0.77, 0, 0.175, 1);
}

/// Interaction states, expressed as overlay opacity over the foreground colour
/// (bone on dark, ink on light). Hue-free: state reads from lightness only.
abstract final class DexStates {
  static const hover = 0.06;
  static const pressed = 0.10;
  static const selected = 0.12;
  static const focusRing = 2.0;
  static const focusGap = 2.0;
  static const pressScale = 0.97;
  static const disabledOpacity = 0.4;
}

/// Window width tiers for the desktop shell.
abstract final class DexBreakpoints {
  static const compact = 1000.0;
  static const wide = 1500.0;

  static bool isCompact(double width) => width < compact;
  static bool isWide(double width) => width >= wide;
}
