import 'package:flutter/material.dart';

/// Dex's gothic skin, applied on top of whichever theme style is active.
///
/// Strictly black and white: ink-black surfaces, bone-white text, grey
/// outlines, Cinzel for headings. Everything reads from the color scheme and
/// text theme, so widgets pick it up without per-screen changes.
/// Dex uses one fixed black-and-white palette. The seed colour, dynamic colour
/// and AMOLED controls from the original app no longer change anything, so the
/// settings page hides them while this is false.
const bool dexCustomColors = false;

const String dexHeadingFont = 'Cinzel';
const String dexBlackletterFont = 'UnifrakturCook';

/// The Dex palette as a complete [ColorScheme]. Feed this to the app theme
/// builders so every component theme (tabs, sliders, switches, progress) is
/// derived from it, rather than patching a finished theme afterwards.
ColorScheme dexColorScheme(Brightness brightness) {
  final base = ColorScheme.fromSeed(
    seedColor: const Color(0xFF808080),
    brightness: brightness,
  );
  return brightness == Brightness.dark ? _darkScheme(base) : _lightScheme(base);
}

ThemeData applyDexGothic(ThemeData theme) {
  final dark = theme.brightness == Brightness.dark;
  final scheme = dark
      ? _darkScheme(theme.colorScheme)
      : _lightScheme(theme.colorScheme);

  TextStyle? heading(TextStyle? style, {double spacing = 0.6}) =>
      style?.copyWith(fontFamily: dexHeadingFont, letterSpacing: spacing);

  TextTheme headings(TextTheme t) => t.copyWith(
    displayLarge: heading(t.displayLarge),
    displayMedium: heading(t.displayMedium),
    displaySmall: heading(t.displaySmall),
    headlineLarge: heading(t.headlineLarge),
    headlineMedium: heading(t.headlineMedium),
    headlineSmall: heading(t.headlineSmall),
    titleLarge: heading(t.titleLarge, spacing: 0.8),
  );

  return theme.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    cardColor: scheme.surfaceContainer,
    dividerColor: scheme.outlineVariant,
    textTheme: headings(
      theme.textTheme,
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
    primaryTextTheme: headings(theme.primaryTextTheme),
  );
}

ColorScheme _darkScheme(ColorScheme base) => base.copyWith(
  primary: const Color(0xFFF2F2F2),
  onPrimary: const Color(0xFF080808),
  primaryContainer: const Color(0xFF2A2A2A),
  onPrimaryContainer: const Color(0xFFF2F2F2),
  secondary: const Color(0xFFBDBDBD),
  onSecondary: const Color(0xFF080808),
  secondaryContainer: const Color(0xFF242424),
  onSecondaryContainer: const Color(0xFFE8E8E8),
  tertiary: const Color(0xFF9E9E9E),
  onTertiary: const Color(0xFF080808),
  tertiaryContainer: const Color(0xFF2E2E2E),
  onTertiaryContainer: const Color(0xFFE0E0E0),
  error: const Color(0xFFE0E0E0),
  onError: const Color(0xFF080808),
  errorContainer: const Color(0xFF3A3A3A),
  onErrorContainer: const Color(0xFFF2F2F2),
  surface: const Color(0xFF050505),
  onSurface: const Color(0xFFF2F2F2),
  surfaceDim: const Color(0xFF030303),
  surfaceBright: const Color(0xFF2A2A2A),
  surfaceContainerLowest: const Color(0xFF020202),
  surfaceContainerLow: const Color(0xFF0C0C0C),
  surfaceContainer: const Color(0xFF131313),
  surfaceContainerHigh: const Color(0xFF1B1B1B),
  surfaceContainerHighest: const Color(0xFF242424),
  onSurfaceVariant: const Color(0xFFA8A8A8),
  outline: const Color(0xFF6A6A6A),
  outlineVariant: const Color(0xFF2E2E2E),
  surfaceTint: Colors.transparent,
);

ColorScheme _lightScheme(ColorScheme base) => base.copyWith(
  primary: const Color(0xFF0A0A0A),
  onPrimary: const Color(0xFFF5F5F5),
  primaryContainer: const Color(0xFFDADADA),
  onPrimaryContainer: const Color(0xFF0A0A0A),
  secondary: const Color(0xFF3A3A3A),
  onSecondary: const Color(0xFFFFFFFF),
  secondaryContainer: const Color(0xFFE4E4E4),
  onSecondaryContainer: const Color(0xFF111111),
  tertiary: const Color(0xFF5A5A5A),
  onTertiary: const Color(0xFFFFFFFF),
  error: const Color(0xFF222222),
  onError: const Color(0xFFFFFFFF),
  surface: const Color(0xFFF2F2F2),
  onSurface: const Color(0xFF0A0A0A),
  surfaceContainerLowest: const Color(0xFFFAFAFA),
  surfaceContainerLow: const Color(0xFFECECEC),
  surfaceContainer: const Color(0xFFE5E5E5),
  surfaceContainerHigh: const Color(0xFFDDDDDD),
  surfaceContainerHighest: const Color(0xFFD4D4D4),
  onSurfaceVariant: const Color(0xFF4A4A4A),
  outline: const Color(0xFF7A7A7A),
  outlineVariant: const Color(0xFFC8C8C8),
  surfaceTint: Colors.transparent,
);
