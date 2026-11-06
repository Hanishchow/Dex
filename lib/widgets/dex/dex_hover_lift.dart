import 'dart:async';

import 'package:flutter/material.dart';

/// Floats [child] a few pixels up and grows it slightly while the pointer is
/// over it, with a small spring overshoot and a soft shadow, so tiles feel
/// like physical cards.
///
/// Rest the pointer on a tile for [peekDelay] and it rises further above its
/// neighbours: a copy is shown in the overlay, scaled up over the other
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
  final _portal = OverlayPortalController();
  Timer? _timer;
  bool _hovered = false;
  bool _peek = false;
  Size _size = Size.zero;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
    if (_peek) _portal.hide();
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
    _portal.show();
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
  Widget _overlayCopy(BuildContext context) => CompositedTransformFollower(
    link: _link,
    showWhenUnlinked: false,
    child: IgnorePointer(
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: _size.width,
        maxWidth: _size.width,
        minHeight: _size.height,
        maxHeight: _size.height,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutBack,
          builder: (context, t, child) {
            final from = 1 + (widget.scale - 1);
            final scale = from + (widget.peekScale - from) * t;
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
                      child: child,
                    ),
                  ),
                ),
              ),
            );
          },
          child: widget.child,
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
        child: OverlayPortal(
          controller: _portal,
          overlayChildBuilder: _overlayCopy,
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
      ),
    );
  }
}

/// A [SliverChildDelegate] that gives every child [DexHoverLift].
class DexLiftDelegate extends SliverChildDelegate {
  const DexLiftDelegate(this.inner);

  final SliverChildDelegate inner;

  @override
  Widget? build(BuildContext context, int index) {
    final child = inner.build(context, index);
    if (child == null) return null;
    final key = child.key;
    return DexHoverLift(key: key is GlobalKey ? null : key, child: child);
  }

  @override
  int? get estimatedChildCount => inner.estimatedChildCount;

  @override
  double? estimateMaxScrollOffset(
    int firstIndex,
    int lastIndex,
    double leadingScrollOffset,
    double trailingScrollOffset,
  ) => inner.estimateMaxScrollOffset(
    firstIndex,
    lastIndex,
    leadingScrollOffset,
    trailingScrollOffset,
  );

  @override
  void didFinishLayout(int firstIndex, int lastIndex) =>
      inner.didFinishLayout(firstIndex, lastIndex);

  @override
  int? findIndexByKey(Key key) => inner.findIndexByKey(key);

  @override
  bool shouldRebuild(covariant DexLiftDelegate oldDelegate) =>
      inner.shouldRebuild(oldDelegate.inner);
}
