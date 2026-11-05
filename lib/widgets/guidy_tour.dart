import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/guidy_ui.dart';

/// One stop of a [GuidyTour]: the widget to highlight ([target], the key on
/// it) and what to say about it. With no target, the card sits in the
/// middle of the screen (a welcome, or a feature that has nothing to point
/// at).
class TourStep {
  const TourStep({this.target, required this.title, required this.body});

  final GlobalKey? target;
  final String title;
  final String body;
}

/// A feature tour: the screen dimmed, a lit cut-out around one feature at a
/// time and a card explaining it, with Skip and Next. Steps whose widget
/// isn't on screen (a tab hidden by Simple mode, say) are left out, and a
/// step whose widget leaves the screen while it shows is passed over.
class GuidyTour {
  GuidyTour._();

  /// Whether screens start their tour by themselves the first time they
  /// open. Replaying from Settings works either way.
  static bool autoStart = true;

  /// The tour on screen, if any.
  static Route<bool>? _open;

  /// Shows [steps] over the screen of [context]. Completes with true when
  /// the rider went through to the end, false when they skipped.
  static Future<bool> show(BuildContext context, List<TourStep> steps) {
    final navigator = Navigator.of(context, rootNavigator: true);
    // The tour draws inside the navigator, which starts below the app's top
    // banner (AppBannerShell), so features are measured from its corner,
    // not the screen's.
    RenderObject? frame() => navigator.context.findRenderObject();
    final visible = steps.where((s) => s.target == null || _rectOf(s.target!, frame()) != null).toList();
    if (visible.isEmpty) return Future.value(true);
    // A see-through route rather than a bare overlay entry: the phone's
    // back button closes the tour (as a skip) instead of leaving it over
    // whatever screen is underneath.
    final route = PageRouteBuilder<bool>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (routeContext, animation, _) => FadeTransition(
        opacity: animation,
        child: _TourOverlay(
          steps: visible,
          firstTarget: visible.first.target == null ? null : _rectOf(visible.first.target!, frame()),
          frame: frame,
          onFinish: (completed) {
            // Usually from the card, with the tour on top. When it ends by
            // itself (its features gone) under something else, take only
            // the tour away.
            final self = ModalRoute.of(routeContext);
            if (self == null || self.isCurrent) {
              Navigator.of(routeContext).pop(completed);
            } else if (self.isActive) {
              self.navigator?.removeRoute(self);
            }
          },
        ),
      ),
    );
    _open = route;
    return navigator.push<bool>(route).then((completed) {
      if (identical(_open, route)) _open = null;
      return completed ?? false;
    });
  }

  /// Takes the tour off the screen at once, with no fade, as when the
  /// screen under it is about to become something else (the trip going to
  /// the floating window). [show] completes with false, as for a skip.
  static void close() {
    final route = _open;
    _open = null;
    if (route != null && route.isActive) route.navigator?.removeRoute(route);
  }

  /// Whether [context]'s screen is the one showing: a tour started under a
  /// dialog, a sheet or another screen would light up widgets nobody can
  /// see. Starting a tour checks this first and waits for another time.
  static bool isOnTop(BuildContext context) => ModalRoute.of(context)?.isCurrent ?? true;

  /// Where [key]'s widget is within [frame] (the navigator the tour is
  /// drawn in), or null when it isn't laid out.
  /// Not to be asked while widgets are building: a screen that has just
  /// dropped the widget still holds it, inactive, until the frame ends, and
  /// asking an inactive widget where it is throws.
  static Rect? _rectOf(GlobalKey key, RenderObject? frame) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final ancestor = frame is RenderBox && frame.attached ? frame : null;
    final rect = box.localToGlobal(Offset.zero, ancestor: ancestor) & box.size;
    if (rect.isEmpty) return null;
    return rect;
  }
}

class _TourOverlay extends StatefulWidget {
  const _TourOverlay({required this.steps, required this.firstTarget, required this.frame, required this.onFinish});

  final List<TourStep> steps;

  /// What features are measured against (see [GuidyTour.show]).
  final RenderObject? Function() frame;

  /// Where the first step's widget was when the tour opened.
  final Rect? firstTarget;
  final ValueChanged<bool> onFinish;

  @override
  State<_TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<_TourOverlay> {
  int _index = 0;

  /// Where the current step's widget is, measured once each frame is done
  /// (see [GuidyTour._rectOf]) rather than while building.
  Rect? _target;
  bool _finished = false;

  bool get _last => _index == widget.steps.length - 1;

  @override
  void initState() {
    super.initState();
    _target = widget.firstTarget;
    _watch();
  }

  /// After every frame drawn while the tour is up, follows the feature if
  /// it moved, and moves on if it left the screen.
  void _watch() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _finished) return;
      _showFrom(_index);
      _watch();
    });
  }

  /// Shows step [index], or the first after it whose widget is still on
  /// screen; the end of the tour when none is.
  void _showFrom(int index) {
    Rect? rect;
    while (true) {
      final key = widget.steps[index].target;
      if (key == null) break;
      rect = GuidyTour._rectOf(key, widget.frame());
      if (rect != null) break;
      if (index == widget.steps.length - 1) {
        _finish(false);
        return;
      }
      index++;
    }
    if (index != _index || rect != _target) {
      setState(() {
        _index = index;
        _target = rect;
      });
    }
  }

  void _finish(bool completed) {
    if (_finished) return;
    _finished = true;
    widget.onFinish(completed);
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_last) {
      _finish(true);
    } else {
      _showFrom(_index + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The room the tour actually has: the screen less the top banner.
    return LayoutBuilder(builder: (context, constraints) => _build(context, constraints.biggest));
  }

  Widget _build(BuildContext context, Size screen) {
    final l10n = AppLocalizations.of(context);
    final step = widget.steps[_index];
    final media = MediaQuery.of(context);
    final hole = step.target == null ? null : _target?.inflate(6);

    // The card goes below the feature when there is room, above otherwise,
    // and in the middle for a step with nothing to point at.
    const cardMargin = 16.0;
    final cardWidth = math.min(screen.width - 2 * cardMargin, 420.0);
    final double? top;
    final double? bottom;
    if (hole == null) {
      top = null;
      bottom = null;
    } else if (hole.center.dy < screen.height / 2) {
      top = hole.bottom + 12;
      bottom = null;
    } else {
      top = null;
      bottom = screen.height - hole.top + 12;
    }

    final card = Material(
      key: const ValueKey('guidy_tour_card'),
      color: context.surfaceCard,
      elevation: 8,
      borderRadius: BorderRadius.circular(GuidyUi.radius),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 10, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.tourStepOf(_index + 1, widget.steps.length),
              style: TextStyle(fontSize: 12, color: context.textSecondary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              step.title,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: GuidyUi.heading(context)),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Text(step.body, style: TextStyle(fontSize: 14, height: 1.4, color: context.textPrimary)),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (!_last)
                  TextButton(
                    onPressed: () => _finish(false),
                    child: Text(l10n.tourSkip, style: TextStyle(color: context.textSecondary)),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.brandBlue),
                  child: Text(_last ? l10n.tourDone : l10n.tourNext),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Stack(
      children: [
        // A tap anywhere on the dimmed screen moves on; nothing under the
        // tour can be tapped while it is open.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _next,
            // The window glides from one feature to the next.
            child: hole == null
                ? CustomPaint(painter: _SpotlightPainter(null))
                : TweenAnimationBuilder<Rect?>(
                    tween: RectTween(end: hole),
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    builder: (context, rect, _) => CustomPaint(painter: _SpotlightPainter(rect)),
                  ),
          ),
        ),
        if (hole == null)
          Center(child: SizedBox(width: cardWidth, child: card))
        else
          Positioned(
            left: (screen.width - cardWidth) / 2,
            width: cardWidth,
            // A very short screen (a floating window) leaves less than the
            // margins: the card then sits at the margin rather than throwing.
            top: top?.clamp(media.padding.top + 8, math.max(media.padding.top + 8, screen.height - 120)),
            bottom: bottom?.clamp(media.padding.bottom + 8, math.max(media.padding.bottom + 8, screen.height - 120)),
            child: card,
          ),
      ],
    );
  }
}

/// The screen dimmed, with a rounded window cut around the feature.
class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter(this.hole);

  final Rect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Path()..addRect(Offset.zero & size);
    final h = hole;
    final path = h == null
        ? dim
        : Path.combine(
            PathOperation.difference,
            dim,
            Path()..addRRect(RRect.fromRectAndRadius(h, const Radius.circular(14))),
          );
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.62));
    if (h != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(h, const Radius.circular(14)),
        Paint()
          ..color = AppColors.brandAmber
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.hole != hole;
}
