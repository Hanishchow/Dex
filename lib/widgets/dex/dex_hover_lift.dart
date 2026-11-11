import 'dart:async';

import 'package:flutter/material.dart';

/// Floats [child] a few pixels up and grows it slightly while the pointer is
/// over it, with a small spring overshoot and a soft shadow, so tiles feel
/// like physical cards.
///
/// Rest the pointer on a tile for [peekDelay] and it rises further above its
/// neighbours: a copy is shown in the root overlay, scaled up over the other
/// tiles, while the original stays put under the pointer. Touch and
/// reduced-motion users get no movement.
class DexHoverLift extends StatefulWidget {
  const DexHoverLift({
    super.key,
    required this.child,
    this.enabled = true,
    this.lift = 6,
    this.scale = 1.03,
    this.peekScale = 1.18,
    this.peekDelay = const Duration(seconds: 2),
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  final Widget child;
  final bool enabled;

  /// How far the tile rises, in logical pixels.
  final double lift;
  final double scale;

  /// Scale of the tile once it has been hovered for [peekDelay].
  final double peekScale;
  final Duration peekDelay;

  /// Rounds the hover shadow; match the tile's corners.
  final BorderRadius borderRadius;

  @override
  State<DexHoverLift> createState() => _DexHoverLiftState();
}

class _DexHoverLiftState extends State<DexHoverLift> {
  final _link = LayerLink();
  OverlayEntry? _entry;
  Timer? _timer;
  bool _hovered = false;
  bool _peek = false;
  Size _size = Size.zero;

  @override
  void dispose() {
    _timer?.cancel();
    _removeEntry();
    super.dispose();
  }

  void _removeEntry() {
    final entry = _entry;
    if (entry == null) return;
    _entry = null;
    entry.remove();
    entry.dispose();
  }

  void _enter() {
    if (_hovered) return;
    setState(() => _hovered = true);
    _timer?.cancel();
    _timer = Timer(widget.peekDelay, _startPeek);
  }

  void _exit() {
    _timer?.cancel();
    if (!_hovered && !_peek) return;
    _removeEntry();
    setState(() {
      _hovered = false;
      _peek = false;
    });
  }

  void _startPeek() {
    if (!mounted || !_hovered) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    _size = box.size;
    // A plain entry in the root overlay: unlike OverlayPortal it does not
    // inherit parent-data widgets (such as a list's keep-alive) from above.
    final themed = InheritedTheme.captureAll(context, widget.child);
    final entry = OverlayEntry(builder: (_) => _overlayCopy(themed));
    Overlay.of(context, rootOverlay: true).insert(entry);
    _entry = entry;
    setState(() => _peek = true);
  }

  Widget _decorated(double t, Widget child) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: widget.borderRadius,
      boxShadow: [
        BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.55 * t.clamp(0.0, 1.0)),
          blurRadius: 22 * t.clamp(0.0, 1.0),
          offset: Offset(0, 12 * t.clamp(0.0, 1.0)),
        ),
      ],
    ),
    child: child,
  );

  /// The enlarged copy that floats over the neighbouring tiles.
  Widget _overlayCopy(Widget child) => Positioned(
    left: 0,
    top: 0,
    child: CompositedTransformFollower(
      link: _link,
      showWhenUnlinked: false,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutBack,
          builder: (context, t, inner) {
            final scale = widget.scale + (widget.peekScale - widget.scale) * t;
            final rise = widget.lift + 14 * t;
            return Transform.translate(
              offset: Offset(0, -rise),
              child: Transform.scale(
                scale: scale,
                child: _decorated(
                  1 + 0.5 * t,
                  Material(
                    type: MaterialType.transparency,
                    child: SizedBox(
                      width: _size.width,
                      height: _size.height,
                      child: inner,
                    ),
                  ),
                ),
              ),
            );
          },
          child: child,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (!widget.enabled || reduce) return widget.child;
    return MouseRegion(
      onEnter: (_) => _enter(),
      onExit: (_) => _exit(),
      child: CompositedTransformTarget(
        link: _link,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: _hovered ? 1.0 : 0.0),
          duration: Duration(milliseconds: _hovered ? 260 : 180),
          curve: _hovered ? Curves.easeOutBack : Curves.easeOutCubic,
          builder: (context, t, child) => Opacity(
            // The overlay copy takes over while the tile is peeking.
            opacity: _peek ? 0 : 1,
            child: Transform.translate(
              offset: Offset(0, -widget.lift * t),
              child: Transform.scale(
                scale: 1 + (widget.scale - 1) * t,
                child: _decorated(t, child!),
              ),
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Gives every child of a builder [delegate] [DexHoverLift]. The lift goes
/// inside the keep-alive and semantics wrappers the delegate adds, so the
/// sliver still finds its parent data where it expects it. Other delegates
/// are returned unchanged.
SliverChildDelegate dexLiftDelegate(SliverChildDelegate delegate) {
  if (delegate is! SliverChildBuilderDelegate) return delegate;
  final builder = delegate.builder;
  return SliverChildBuilderDelegate(
    (context, index) {
      final child = builder(context, index);
      return child == null ? null : DexHoverLift(child: child);
    },
    childCount: delegate.childCount,
    findChildIndexCallback: delegate.findChildIndexCallback,
    addAutomaticKeepAlives: delegate.addAutomaticKeepAlives,
    addRepaintBoundaries: delegate.addRepaintBoundaries,
    addSemanticIndexes: delegate.addSemanticIndexes,
    semanticIndexCallback: delegate.semanticIndexCallback,
    semanticIndexOffset: delegate.semanticIndexOffset,
  );
}
