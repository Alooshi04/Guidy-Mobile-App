import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// One button on a [GuidyToolRail].
class GuidyToolRailItem {
  const GuidyToolRailItem({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.activeIcon,
    this.active = false,
    this.key,
  });

  final IconData icon;

  /// Shown instead of [icon] while [active] (a filled bookmark, say).
  final IconData? activeIcon;
  final String tooltip;
  final VoidCallback onTap;

  /// On (live sharing, trip saved): tinted background and a dot.
  final bool active;
  final Key? key;
}

/// The tool rail: one horizontal card on the map edge. The menu button sits
/// at the screen-edge side (end) and folds the rail into itself; [lead] and
/// [items] run from it towards the start side, so the rail grows left in LTR
/// and right in RTL. Whatever sits under the rail is not pushed down by it.
class GuidyToolRail extends StatefulWidget {
  const GuidyToolRail({
    super.key,
    required this.lead,
    required this.items,
    required this.showTooltip,
    required this.hideTooltip,
    this.initiallyExpanded = true,
  });

  final GuidyToolRailItem lead;
  final List<GuidyToolRailItem> items;
  final String showTooltip;
  final String hideTooltip;
  final bool initiallyExpanded;

  @override
  State<GuidyToolRail> createState() => _GuidyToolRailState();
}

class _GuidyToolRailState extends State<GuidyToolRail> {
  // Every button is a 44dp-wide tap target; the rail is as tall as the menu tab.
  static const double _btnW = 44;
  static const double _tabH = 46;

  late bool _expanded = widget.initiallyExpanded;

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final fill = context.surfaceCard;
    final shadow = context.isDark ? Colors.black.withValues(alpha: 0.45) : AppColors.brandNavy.withValues(alpha: 0.22);

    final menu = _RailButton(
      key: const ValueKey('guidy-tool-rail-menu'),
      item: GuidyToolRailItem(
        icon: _expanded ? Icons.menu_open_rounded : Icons.menu_rounded,
        tooltip: _expanded ? widget.hideTooltip : widget.showTooltip,
        onTap: _toggle,
      ),
      width: _btnW,
      height: _tabH,
      expanded: _expanded,
    );

    final tools = [widget.lead, ...widget.items];
    final width = _expanded ? _btnW * (tools.length + 1) : _btnW;
    final Widget child = SizedBox(
      key: ValueKey(_expanded ? 'open' : 'folded'),
      width: width,
      height: _tabH,
      child: CustomPaint(
        painter: _RailPainter(size: Size(width, _tabH), fill: fill, shadow: shadow),
        // A Row follows the text direction: the last child is at the
        // screen edge, the first furthest from it.
        child: Row(
          children: [
            if (_expanded)
              for (final item in tools) _RailButton(item: item, width: _btnW, height: _tabH),
            menu,
          ],
        ),
      ),
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.topEnd,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1).animate(animation),
          alignment: rtl ? Alignment.topLeft : Alignment.topRight,
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({super.key, required this.item, required this.width, required this.height, this.expanded});

  final GuidyToolRailItem item;
  final double width;
  final double height;

  /// Set on the menu tab only, for its expanded/collapsed semantics.
  final bool? expanded;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: item.key,
      width: width,
      height: height,
      child: Semantics(
        button: true,
        selected: item.activeIcon != null || item.active ? item.active : null,
        expanded: expanded,
        child: Tooltip(
          message: item.tooltip,
          child: InkResponse(
            onTap: item.onTap,
            radius: 22,
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: item.active ? AppColors.brandBlue.withValues(alpha: context.isDark ? 0.28 : 0.14) : Colors.transparent,
                    ),
                  ),
                  Icon(item.active ? (item.activeIcon ?? item.icon) : item.icon, size: 22, color: AppColors.brandBlue),
                  if (item.active && item.activeIcon == null)
                    PositionedDirectional(
                      top: 4,
                      end: 3,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.brandBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: context.surfaceCard, width: 1.5),
                        ),
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

/// Paints the rail's card: a rounded bar, as wide as the buttons it holds.
class _RailPainter extends CustomPainter {
  _RailPainter({required this.size, required this.fill, required this.shadow});

  final Size size;
  final Color fill;
  final Color shadow;

  static const double _r = 14;

  Path _shape(Size size) => Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(_r)));

  @override
  void paint(Canvas canvas, Size size) {
    final path = _shape(size);
    canvas.drawPath(
      path.shift(const Offset(0, 4)),
      Paint()
        ..color = shadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawPath(path, Paint()..color = fill);
  }

  @override
  bool? hitTest(Offset position) => _shape(size).contains(position);

  @override
  bool shouldRepaint(_RailPainter old) => old.size != size || old.fill != fill || old.shadow != shadow;
}
