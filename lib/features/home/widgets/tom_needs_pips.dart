import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/needs_model.dart';

/// Compact critical-need hints only — keeps the Tom hero uncluttered.
class TomNeedsPips extends StatelessWidget {
  const TomNeedsPips({
    super.key,
    required this.needs,
    this.threshold = 28,
  });

  final NeedsModel needs;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    final critical = <(NeedType, IconData, Color)>[
      (NeedType.hunger, Icons.restaurant_rounded, AppColors.hunger),
      (NeedType.toilet, Icons.wc_rounded, AppColors.toilet),
      (NeedType.energy, Icons.battery_alert_rounded, AppColors.energy),
      (NeedType.cleanliness, Icons.water_drop_rounded, AppColors.cleanliness),
      (NeedType.fun, Icons.sports_esports_rounded, AppColors.fun),
      (NeedType.social, Icons.favorite_rounded, AppColors.social),
    ].where((e) => needs.of(e.$1) < threshold).toList();

    if (critical.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in critical.take(3))
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _Pip(
              icon: item.$2,
              color: item.$3,
              value: needs.of(item.$1),
            ),
          ),
      ],
    );
  }
}

class _Pip extends StatelessWidget {
  const _Pip({
    required this.icon,
    required this.color,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final double value;

  @override
  Widget build(BuildContext context) {
    final urgent = value < 15;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
        border: Border.all(
          color: urgent ? color : Colors.white54,
          width: urgent ? 2.5 : 1.5,
        ),
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }
}
