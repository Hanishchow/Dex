import 'package:flutter/material.dart';

/// Floats [child] a few pixels up and grows it slightly while the pointer is
/// over it, with a small spring overshoot and a soft shadow, so tiles feel
/// like physical cards. Touch and reduced-motion users get no movement.
class DexHoverLift extends StatefulWidget {
  const DexHoverLift({
    super.key,
    required this.child,
    this.enabled = true,
    this.lift = 6,
    this.scale = 1.03,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  final Widget child;
  final bool enabled;

  /// How far the tile rises, in logical pixels.
  final double lift;
  final double scale;

  /// Rounds the hover shadow; match the tile's corners.
  final BorderRadius borderRadius;

  @override
  State<DexHoverLift> createState() => _DexHoverLiftState();
}

class _DexHoverLiftState extends State<DexHoverLift> {
  bool _hovered = false;

  void _set(bool value) {
    if (_hovered != value) setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (!widget.enabled || reduce) return widget.child;
    final up = _hovered;
    return MouseRegion(
      onEnter: (_) => _set(true),
      onExit: (_) => _set(false),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: up ? 1.0 : 0.0),
        duration: Duration(milliseconds: up ? 260 : 180),
        curve: up ? Curves.easeOutBack : Curves.easeOutCubic,
        builder: (context, t, child) => Transform.translate(
          offset: Offset(0, -widget.lift * t),
          child: Transform.scale(
            scale: 1 + (widget.scale - 1) * t,
            child: DecoratedBox(
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
            ),
          ),
        ),
        child: widget.child,
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
