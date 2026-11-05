import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// Animated shimmer skeleton card matching the exact structure and geometry of
/// RouteOptionsScreen's route cards. Eliminates the blank-screen delay feeling
/// by providing immediate visual structure while the routing engine computes paths.
class RouteCardSkeletonList extends StatefulWidget {
  const RouteCardSkeletonList({super.key, this.mapHeight});

  /// Height of a map placeholder above the cards, or null for no map.
  final double? mapHeight;

  @override
  State<RouteCardSkeletonList> createState() => _RouteCardSkeletonListState();
}

class _RouteCardSkeletonListState extends State<RouteCardSkeletonList>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _shimmerAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = context.isDark;

    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (context, child) {
        final shimmerValue = _shimmerAnim.value;
        final baseAlpha = isDark ? 0.08 : 0.06;
        final highlightAlpha = isDark ? 0.22 : 0.16;
        final currentAlpha = baseAlpha + (highlightAlpha - baseAlpha) * shimmerValue;
        final shimmerColor = isDark ? Colors.white : Colors.black;

        final list = ListView(
          padding: const EdgeInsets.all(20),
          physics: const NeverScrollableScrollPhysics(),
          children: [
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryTeal.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    l10n.availableRoutes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: context.textPrimary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSkeletonCard(context, currentAlpha, shimmerColor, isDark, tierWidth: 105),
            const SizedBox(height: 16),
            _buildSkeletonCard(context, currentAlpha, shimmerColor, isDark, tierWidth: 85),
            const SizedBox(height: 16),
            _buildSkeletonCard(context, currentAlpha, shimmerColor, isDark, tierWidth: 95),
          ],
        );
        if (widget.mapHeight == null) return list;
        // The loaded screen has the map above the cards; hold its place so
        // the layout doesn't jump when the routes arrive.
        return Column(
          children: [
            Container(
              key: const ValueKey('route-map-skeleton'),
              height: widget.mapHeight,
              width: double.infinity,
              color: shimmerColor.withValues(alpha: currentAlpha),
              alignment: Alignment.center,
              child: Icon(Icons.map_outlined, size: 40, color: context.textPrimary.withValues(alpha: 0.25)),
            ),
            Expanded(child: list),
          ],
        );
      },
    );
  }

  Widget _buildSkeletonCard(
    BuildContext context,
    double alpha,
    Color shimmerColor,
    bool isDark, {
    required double tierWidth,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Tier pill + Fare badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _bone(tierWidth, 24, alpha, shimmerColor, 10),
              _bone(65, 24, alpha, shimmerColor, 10),
            ],
          ),
          const SizedBox(height: 14),

          // Duration + distance line
          Row(
            children: [
              _bone(90, 26, alpha, shimmerColor, 6),
              const SizedBox(width: 8),
              _bone(55, 16, alpha, shimmerColor, 4),
            ],
          ),
          const SizedBox(height: 12),

          // Walk & transfers capsules
          Row(
            children: [
              _bone(60, 20, alpha, shimmerColor, 6),
              const SizedBox(width: 8),
              _bone(70, 20, alpha, shimmerColor, 6),
            ],
          ),
          const SizedBox(height: 14),

          // Transit leg pills row
          Row(
            children: [
              _bone(45, 24, alpha, shimmerColor, 8),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, size: 14, color: shimmerColor.withValues(alpha: alpha)),
              const SizedBox(width: 6),
              _bone(55, 24, alpha, shimmerColor, 8),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, size: 14, color: shimmerColor.withValues(alpha: alpha)),
              const SizedBox(width: 6),
              _bone(45, 24, alpha, shimmerColor, 8),
            ],
          ),
          const SizedBox(height: 12),

          // Subtitle
          _bone(180, 14, alpha, shimmerColor, 4),
        ],
      ),
    );
  }

  Widget _bone(double width, double height, double alpha, Color color, double radius) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
