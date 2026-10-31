import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dex_tokens.dart';

/// The one interactive wrapper for Dex surfaces: pointer cursor, a hover fill,
/// a 0.97 press-scale on pointer-down, and a keyboard focus ring that never
/// shows on mouse clicks. Enter and Space activate it.
///
/// Wrap cards, rows, tiles and custom buttons with it instead of a bare
/// `GestureDetector`, which gives none of this on desktop.
class DexPressable extends StatefulWidget {
  const DexPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onSecondaryTap,
    this.onDoubleTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.selected = false,
    this.hoverFill = true,
    this.pressScale = true,
    this.autofocus = false,
    this.semanticLabel,
    this.focusNode,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onSecondaryTap;
  final VoidCallback? onDoubleTap;
  final BorderRadius borderRadius;
  final bool selected;

  /// Tint the surface on hover. Turn off when the child draws its own state.
  final bool hoverFill;

  /// Scale down slightly while pressed.
  final bool pressScale;
  final bool autofocus;
  final String? semanticLabel;
  final FocusNode? focusNode;

  bool get enabled => onTap != null || onDoubleTap != null;

  @override
  State<DexPressable> createState() => _DexPressableState();
}

class _DexPressableState extends State<DexPressable> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focusVisible = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final enabled = widget.enabled;
    final fg = scheme.onSurface;

    var overlay = 0.0;
    if (widget.selected) overlay = DexStates.selected;
    if (enabled && _hovered && widget.hoverFill) {
      overlay = overlay > DexStates.hover ? overlay : DexStates.hover;
    }
    if (enabled && _pressed) overlay = DexStates.pressed;

    final scale = enabled && _pressed && widget.pressScale && !reduce
        ? DexStates.pressScale
        : 1.0;

    return Semantics(
      button: enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: enabled,
        autofocus: widget.autofocus,
        focusNode: widget.focusNode,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        onShowFocusHighlight: (v) => setState(() => _focusVisible = v),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        child: Listener(
          onPointerDown: (e) {
            if (enabled && e.buttons == kPrimaryButton) _setPressed(true);
          },
          onPointerUp: (_) => _setPressed(false),
          onPointerCancel: (_) => _setPressed(false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            onDoubleTap: widget.onDoubleTap,
            onSecondaryTap: widget.onSecondaryTap,
            child: AnimatedScale(
              scale: scale,
              duration: reduce ? Duration.zero : DexMotion.press,
              curve: DexMotion.out,
              child: AnimatedContainer(
                duration: reduce ? Duration.zero : DexMotion.hover,
                curve: DexMotion.out,
                foregroundDecoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  color: fg.withValues(alpha: overlay),
                  border: _focusVisible
                      ? Border.all(color: fg, width: DexStates.focusRing)
                      : null,
                ),
                child: Opacity(
                  opacity: enabled ? 1 : DexStates.disabledOpacity,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
