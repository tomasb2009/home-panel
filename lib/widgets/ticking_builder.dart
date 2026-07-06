import 'dart:async';

import 'package:flutter/widgets.dart';

/// Rebuilds [builder] with the current time on a fixed [interval]. Keeps the
/// rebuild scope tiny (just the clock/date/greeting texts).
class TickingBuilder extends StatefulWidget {
  const TickingBuilder({
    super.key,
    required this.builder,
    this.interval = const Duration(seconds: 1),
  });

  final Widget Function(BuildContext context, DateTime now) builder;
  final Duration interval;

  @override
  State<TickingBuilder> createState() => _TickingBuilderState();
}

class _TickingBuilderState extends State<TickingBuilder> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.interval, (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now);
}
