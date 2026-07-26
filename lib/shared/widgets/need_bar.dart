import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/enums.dart';

class NeedBar extends StatelessWidget {
  const NeedBar({
    super.key,
    required this.type,
    required this.value,
    this.compact = false,
  });

  final NeedType type;
  final double value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      NeedType.hunger => AppColors.hunger,
      NeedType.cleanliness => AppColors.cleanliness,
      NeedType.energy => AppColors.energy,
      NeedType.fun => AppColors.fun,
      NeedType.social => AppColors.social,
      NeedType.toilet => AppColors.toilet,
    };
    final icon = switch (type) {
      NeedType.hunger => Icons.restaurant_rounded,
      NeedType.cleanliness => Icons.water_drop_rounded,
      NeedType.energy => Icons.bolt_rounded,
      NeedType.fun => Icons.sports_esports_rounded,
      NeedType.social => Icons.chat_bubble_rounded,
      NeedType.toilet => Icons.wc_rounded,
    };
    final label = switch (type) {
      NeedType.hunger => 'Голод',
      NeedType.cleanliness => 'Чистота',
      NeedType.energy => 'Енергія',
      NeedType.fun => 'Гра',
      NeedType.social => 'Спілкування',
      NeedType.toilet => 'Туалет',
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: compact ? 16 : 18, color: color),
        const SizedBox(height: 4),
        SizedBox(
          width: compact ? 36 : 44,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (value / 100).clamp(0, 1),
              minHeight: compact ? 5 : 6,
              backgroundColor: color.withValues(alpha: 0.18),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 9,
                  color: AppColors.brandInk.withValues(alpha: 0.7),
                ),
          ),
        ],
      ],
    );
  }
}

class NeedsRow extends StatelessWidget {
  const NeedsRow({super.key, required this.needs});

  final Map<NeedType, double> needs;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: NeedType.values
          .map((t) => NeedBar(type: t, value: needs[t] ?? 0))
          .toList(),
    );
  }
}
