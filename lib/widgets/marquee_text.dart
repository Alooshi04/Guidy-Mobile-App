import 'package:flutter/material.dart';

/// One line of text that never shrinks and never cuts off: when it is wider
/// than its slot it slides slowly from its start to its end, rests, and
/// starts over, so a long line name reads in order at its normal size.
///
/// It is clipped to its own box, so the sliding text can't reach the
/// buttons or icons next to it. Text that fits is a plain [Text].
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  /// Scroll speed, in logical pixels per second.
  final double velocity;

  /// How long the start is shown before scrolling, and the end after.
  final Duration pause;

  const MarqueeText(
    this.text, {
    super.key,
    this.style,
    this.velocity = 30,
    this.pause = const Duration(milliseconds: 1400),
  });

  /// Off in widget tests (flutter_test_config.dart): an endless animation
  /// never lets pumpAndSettle settle. The marquee's own test turns it on.
  static bool animate = true;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  /// The overflow the current run was set up for; a new width restarts it.
  double _runFor = 0;

  // Both are called from layout, so the controller is touched after the
  // frame: changing it mid-layout would mark the text dirty during layout.
  void _run(double overflow) {
    if (overflow == _runFor) return;
    _runFor = overflow;
    final scrollMs = (overflow / widget.velocity * 1000).round();
    final pauseMs = widget.pause.inMilliseconds;
    _controller.duration = Duration(milliseconds: pauseMs * 2 + scrollMs);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _runFor == overflow) _controller.repeat();
    });
  }

  void _stop() {
    if (_runFor == 0) return;
    _runFor = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _runFor == 0) _controller.reset();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The scroll position for an animation [t] in 0..1: rest at the start,
  /// slide at constant speed, rest at the end.
  double _offset(double t, double overflow) {
    final total = _controller.duration!.inMilliseconds;
    final pause = widget.pause.inMilliseconds / total;
    if (t <= pause) return 0;
    if (t >= 1 - pause) return overflow;
    return overflow * (t - pause) / (1 - 2 * pause);
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    final direction = Directionality.of(context);
    return LayoutBuilder(builder: (context, box) {
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: style),
        textDirection: direction,
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final textWidth = painter.width;
      final height = painter.height;
      painter.dispose();
      final overflow = textWidth - box.maxWidth;
      final canMove = MarqueeText.animate && !MediaQuery.of(context).disableAnimations;
      if (!box.maxWidth.isFinite || overflow <= 0.5 || !canMove) {
        _stop();
        return Text(
          widget.text,
          style: widget.style,
          maxLines: 1,
          softWrap: false,
          overflow: overflow > 0.5 && box.maxWidth.isFinite ? TextOverflow.ellipsis : TextOverflow.clip,
        );
      }
      _run(overflow);
      // Right-to-left text starts at the right edge, so it slides right.
      final sign = direction == TextDirection.rtl ? 1.0 : -1.0;
      return Semantics(
        label: widget.text,
        excludeSemantics: true,
        child: ClipRect(
          child: SizedBox(
            width: box.maxWidth,
            height: height,
            child: OverflowBox(
              alignment: AlignmentDirectional.centerStart,
              minWidth: 0,
              maxWidth: double.infinity,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) => Transform.translate(
                  offset: Offset(sign * _offset(_controller.value, overflow), 0),
                  child: child,
                ),
                child: Text(widget.text, style: widget.style, maxLines: 1, softWrap: false),
              ),
            ),
          ),
        ),
      );
    });
  }
}
