import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One action a [SwipeZoneRow] can arm while the finger is still down.
///
/// [onRun] is only called on release, never while the finger moves — that is
/// the whole point of the zoned swipe: a careless long drag must not delete
/// anything.
@immutable
class SwipeZoneAction {
  final String label;
  final IconData icon;
  final Color color;

  /// Icon/label colour. White reads on every action colour except the
  /// near-white "menu" surface, which passes its own.
  final Color foreground;
  final VoidCallback onRun;

  const SwipeZoneAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onRun,
    this.foreground = Colors.white,
  });
}

/// Where the swipe zones of a row [width] pixels wide begin.
///
/// The zones are laid out in the travel between [armStart] (a short, deliberate
/// drag — anything shorter cancels) and [menuFraction] of the row (a full
/// swipe, which opens the menu instead of running the last action). The
/// remaining travel is split evenly, so every zone is equally easy to stop in
/// and the layout still works on a narrow phone.
@immutable
class SwipeZoneGeometry {
  /// Travel before the first zone arms. Roughly 9 mm on a 1080px phone: long
  /// enough that a flick while scrolling arms nothing, short enough to reach
  /// with the thumb alone.
  static const double armStart = 56;

  /// Fraction of the row that must be crossed for the menu to arm.
  static const double menuFraction = 0.88;

  /// Row width in logical pixels.
  final double width;

  /// Number of action zones before the menu.
  final int count;

  /// Whether a menu zone sits behind the last action zone.
  final bool hasMenu;

  const SwipeZoneGeometry({
    required this.width,
    required this.count,
    required this.hasMenu,
  });

  /// Travel at which the menu arms. Without a menu zone the last action zone
  /// simply runs to the edge.
  double get menuStart => hasMenu ? width * menuFraction : double.infinity;

  /// Travel the action zones share between them.
  double get _actionSpan {
    final end = hasMenu ? menuStart : width;
    return end - armStart;
  }

  /// Width of a single action zone.
  double get zoneWidth => count <= 0 ? 0 : _actionSpan / count;

  /// Travel at which zone [index] arms.
  double startOf(int index) => armStart + zoneWidth * index;

  /// Index armed at [travel] pixels of drag: `null` while the drag is too
  /// short to arm anything, [count] once the row is dragged far enough to open
  /// the menu.
  int? armedAt(double travel) {
    if (travel >= menuStart) return count;
    if (travel < armStart || count <= 0 || zoneWidth <= 0) return null;
    final index = ((travel - armStart) / zoneWidth).floor();
    return index.clamp(0, count - 1);
  }
}

/// A row whose swipe reveals a sequence of coloured action zones.
///
/// Dragging left crosses [endActions] in order (shortest drag first). The
/// armed action fills the revealed area, so the user always sees what a
/// release would do, and crossing into a new zone ticks the haptics. Nothing
/// runs until the finger lifts; dragging all the way to [endMenu] arms the
/// menu instead of the last action, so a full swipe can never destroy
/// anything by itself.
///
/// Dragging right arms the single [startAction] the same way.
///
/// The row does not clip itself — the caller keeps its corner grading (see
/// `AppShapes.row`) by wrapping this in the `ClipRRect` it already had.
class SwipeZoneRow extends StatefulWidget {
  /// Left-swipe actions, shortest drag first.
  final List<SwipeZoneAction> endActions;

  /// Armed at the far left end instead of a destructive action.
  final SwipeZoneAction? endMenu;

  /// Right-swipe action (one zone only).
  final SwipeZoneAction? startAction;

  final Widget child;

  const SwipeZoneRow({
    super.key,
    required this.child,
    this.endActions = const [],
    this.endMenu,
    this.startAction,
  });

  @override
  State<SwipeZoneRow> createState() => _SwipeZoneRowState();
}

class _SwipeZoneRowState extends State<SwipeZoneRow>
    with SingleTickerProviderStateMixin {
  /// Width of the icon+label block drawn in the revealed strip. It is centred
  /// in the strip and clipped, so it grows into view instead of jumping.
  static const double _labelWidth = 96;

  late final AnimationController _spring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  Animation<double>? _release;

  /// Current offset of the row. Negative = dragged left.
  double _dx = 0;

  /// Armed left zone; `endActions.length` means the menu is armed.
  int? _armed;

  /// Armed right (start) action.
  bool _startArmed = false;

  @override
  void initState() {
    super.initState();
    _spring.addListener(() {
      setState(() => _dx = _release?.value ?? 0);
    });
    _spring.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      // The colour stays until the row is back home, then the strip is gone
      // anyway — clearing it earlier makes the release flicker.
      setState(() {
        _armed = null;
        _startArmed = false;
      });
    });
  }

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  SwipeZoneGeometry _geometry(double width) => SwipeZoneGeometry(
    width: width,
    count: widget.endActions.length,
    hasMenu: widget.endMenu != null,
  );

  void _onStart(DragStartDetails _) {
    _spring.stop();
  }

  void _onUpdate(DragUpdateDetails details, double width) {
    final maxEnd = widget.endActions.isEmpty && widget.endMenu == null
        ? 0.0
        : width;
    // The right swipe has a single zone, so it never needs the whole row.
    final maxStart = widget.startAction == null ? 0.0 : width * 0.4;
    final next = (_dx + details.delta.dx).clamp(-maxEnd, maxStart);

    final geometry = _geometry(width);
    final armed = next < 0 ? geometry.armedAt(-next) : null;
    final startArmed = next > 0 && next >= SwipeZoneGeometry.armStart;

    // One tick per newly entered zone — also when swiping back into a zone
    // already visited, because that is a real change of what will happen.
    // Leaving every zone (nothing armed) stays silent on purpose.
    final tick =
        (armed != null && armed != _armed) || (startArmed && !_startArmed);

    setState(() {
      _dx = next;
      _armed = armed;
      _startArmed = startArmed;
    });
    if (tick) HapticFeedback.selectionClick();
  }

  void _onEnd() {
    final action = _pending();
    _settle();
    // Runs last: a delete removes this row from the tree and disposes us.
    action?.onRun();
  }

  SwipeZoneAction? _pending() {
    if (_dx > 0) return _startArmed ? widget.startAction : null;
    final armed = _armed;
    if (armed == null) return null;
    if (armed >= widget.endActions.length) return widget.endMenu;
    return widget.endActions[armed];
  }

  void _settle() {
    _release = Tween<double>(
      begin: _dx,
      end: 0,
    ).animate(CurvedAnimation(parent: _spring, curve: Curves.easeOutCubic));
    _spring.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // The row must sit exactly under the finger from the touch down, so
          // the zone the user sees is the zone the travel says. The default
          // (`start`) throws the touch slop away and the row lags 18px behind.
          dragStartBehavior: DragStartBehavior.down,
          onHorizontalDragStart: _onStart,
          onHorizontalDragUpdate: (d) => _onUpdate(d, width),
          onHorizontalDragEnd: (_) => _onEnd(),
          onHorizontalDragCancel: _settle,
          child: Stack(
            children: [
              Positioned.fill(child: _background()),
              Transform.translate(offset: Offset(_dx, 0), child: widget.child),
            ],
          ),
        );
      },
    );
  }

  Widget _background() {
    final reveal = _dx.abs();
    if (reveal < 0.5) return const SizedBox.shrink();

    final toStart = _dx > 0;
    final armed = toStart ? _startArmed : _armed != null;
    // Before the first zone arms the upcoming action is shown dimmed: the user
    // sees where the drag is heading, and that releasing now does nothing.
    final SwipeZoneAction? action = toStart
        ? widget.startAction
        : (_pending() ??
              (widget.endActions.isEmpty
                  ? widget.endMenu
                  : widget.endActions.first));
    if (action == null) return const SizedBox.shrink();

    return ColoredBox(
      color: armed ? action.color : action.color.withValues(alpha: 0.35),
      child: Align(
        alignment: toStart ? Alignment.centerLeft : Alignment.centerRight,
        child: ClipRect(
          child: SizedBox(
            width: reveal,
            height: double.infinity,
            child: OverflowBox(
              minWidth: _labelWidth,
              maxWidth: _labelWidth,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(action.icon, size: 18, color: action.foreground),
                  const SizedBox(height: 3),
                  Text(
                    action.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1,
                      fontWeight: FontWeight.w600,
                      color: action.foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
