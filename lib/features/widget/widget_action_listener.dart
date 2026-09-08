import 'dart:async';

import 'package:flutter/material.dart';

import 'widget_service.dart';

/// Delivers home screen widget taps to the shell.
///
/// Two paths reach the same callback: the intent that cold-started the app
/// (pulled once after the first frame) and every later tap while the app is
/// already running (a method call from the activity). Both are handled here so
/// the shell only has to implement [onAction].
class WidgetActionListener extends StatefulWidget {
  const WidgetActionListener({
    super.key,
    required this.onAction,
    required this.child,
  });

  final Future<void> Function(WidgetAction action) onAction;
  final Widget child;

  @override
  State<WidgetActionListener> createState() => _WidgetActionListenerState();
}

class _WidgetActionListenerState extends State<WidgetActionListener> {
  StreamSubscription<WidgetAction>? _subscription;

  @override
  void initState() {
    super.initState();
    WidgetService.installActionHandler();
    _subscription = WidgetService.actions.listen(_dispatch);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final launch = await WidgetService.takeLaunchAction();
      if (launch != null) _dispatch(launch);
    });
  }

  void _dispatch(WidgetAction action) {
    if (!mounted) return;
    widget.onAction(action);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
