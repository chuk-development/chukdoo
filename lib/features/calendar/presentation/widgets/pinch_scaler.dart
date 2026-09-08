import 'package:flutter/material.dart';

/// The two-finger zoom both calendar grids use: the time grid scales its hour
/// row with it, the month grid its week row.
///
/// ## Why raw pointers and not a scale recognizer
///
/// A `ScaleGestureRecognizer` enters the gesture arena with a *single* pointer
/// as well, so it would beat the horizontal pager and the vertical scroll to
/// the first finger and both would stop working. A [Listener] never enters the
/// arena: one finger keeps paging and scrolling exactly as before, and only
/// the second finger starts a zoom.
///
/// ## Who owns the value
///
/// The host owns the settled size — it comes from the settings and arrives as
/// [value]. While the fingers are down this widget draws with its own live
/// size and hands it to [builder] together with [pinching]; the host uses that
/// flag to freeze its pager and its scroll physics, because a pinch that is
/// allowed to scroll fights its own anchor. When the last finger lifts, the
/// size is reported once through [onSettled] — writing on every frame would
/// hammer the settings box.
///
/// The live size is dropped again as soon as a *different* [value] comes back
/// in, not at the end of the gesture: dropping it earlier would draw the old
/// size for the one frame between the report and the setting landing.
class PinchScaler extends StatefulWidget {
  /// Size of one row as the host currently has it stored. In a grid that fits
  /// itself to the viewport this is the fitted size, so a pinch starts from
  /// what the user actually sees.
  final double value;

  /// Range the pinch may reach. Both ends are the host's, because an hour row
  /// and a week row stop being useful at different sizes.
  final double min;
  final double max;

  /// The size the fingers settled on, once, when the last finger lifts.
  final ValueChanged<double>? onSettled;

  /// The scroll view the grid lives in. It is anchored so the row under the
  /// fingers stays under the fingers.
  final ScrollController scrollController;

  /// Padding above the first row *inside* the scroll view. The anchor has to
  /// subtract it to reach grid coordinates.
  final double topPadding;

  /// Builds the grid at the size it is drawn with right now. [pinching] is
  /// true from the second finger going down until the last one lifts.
  final Widget Function(BuildContext context, double value, bool pinching)
  builder;

  const PinchScaler({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.scrollController,
    required this.builder,
    this.onSettled,
    this.topPadding = 0,
  });

  @override
  State<PinchScaler> createState() => _PinchScalerState();
}

class _PinchScalerState extends State<PinchScaler> {
  /// Every finger currently on the grid, by pointer id, in the coordinates of
  /// this widget.
  final Map<int, Offset> _pointers = {};

  /// True between the second finger going down and the last one lifting.
  bool _pinching = false;

  /// Size while the fingers are on the grid, and until the persisted value
  /// comes back. Null means "whatever the host says".
  double? _live;

  double _startSpan = 0;
  double _startValue = 0;

  /// Where the fingers met and where the grid stood when the pinch began —
  /// together they keep the row under the fingers under the fingers.
  double _startFocalY = 0;
  double _startOffset = 0;

  /// The size the grid draws with right now.
  double get _value => _live ?? widget.value;

  @override
  void didUpdateWidget(PinchScaler oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The pinched size has arrived back through the settings, so the local
    // copy can go.
    if (!_pinching && _live != null && widget.value != oldWidget.value) {
      _live = null;
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length == 2) _begin();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.localPosition;
    if (_pinching) _update();
  }

  void _onPointerEnd(PointerEvent event) {
    if (_pointers.remove(event.pointer) == null) return;
    // One finger left is a pan again, so the zoom settles where it is.
    if (_pointers.length < 2) _end();
  }

  /// The two fingers the zoom is measured between. A third finger is ignored
  /// rather than allowed to jump the span.
  List<Offset> get _points => _pointers.values.take(2).toList();

  void _begin() {
    final points = _points;
    final span = (points[0] - points[1]).distance;
    // Two fingers down in the same spot have no span to scale from.
    if (span < 1) return;

    _startSpan = span;
    _startValue = _value;
    _startFocalY = (points[0].dy + points[1].dy) / 2;
    _startOffset = widget.scrollController.hasClients
        ? widget.scrollController.offset
        : 0;

    setState(() {
      _pinching = true;
      _live = _startValue;
    });
  }

  void _update() {
    final points = _points;
    if (points.length < 2 || _startSpan <= 0) return;

    final span = (points[0] - points[1]).distance;
    final next = (_startValue * span / _startSpan).clamp(
      widget.min,
      widget.max,
    );
    if (next == _live) return;

    setState(() => _live = next);

    // The scroll extent only grows once the taller grid is laid out, so the
    // anchor is corrected after that frame, not during this one.
    final factor = next / _startValue;
    final anchoredY = _startOffset + _startFocalY - widget.topPadding;
    final target = anchoredY * factor - (_startFocalY - widget.topPadding);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.scrollController.hasClients) return;
      widget.scrollController.jumpTo(
        target.clamp(0.0, widget.scrollController.position.maxScrollExtent),
      );
    });
  }

  void _end() {
    if (!_pinching) return;
    _pinching = false;

    final settled = _live;
    if (settled != null) widget.onSettled?.call(settled);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      child: widget.builder(context, _value, _pinching),
    );
  }
}
