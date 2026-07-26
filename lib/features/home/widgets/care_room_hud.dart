import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/needs_model.dart';
import 'tom_style_ui.dart';

/// Shared top bar for care rooms (kitchen / bath / bedroom).
class CareRoomHud extends StatelessWidget {
  const CareRoomHud({
    super.key,
    required this.age,
    required this.progress,
    required this.coins,
    required this.gems,
    required this.needs,
    required this.focusNeed,
  });

  final int age;
  final double progress;
  final int coins;
  final int gems;
  final NeedsModel needs;
  final NeedType focusNeed;

  @override
  Widget build(BuildContext context) {
    final value = needs.of(focusNeed);
    final (label, color, icon) = switch (focusNeed) {
      NeedType.hunger => ('Голод', AppColors.hunger, Icons.restaurant_rounded),
      NeedType.cleanliness => (
          'Чистота',
          AppColors.cleanliness,
          Icons.water_drop_rounded
        ),
      NeedType.energy => ('Енергія', AppColors.energy, Icons.bolt_rounded),
      NeedType.toilet => ('Туалет', AppColors.toilet, Icons.wc_rounded),
      NeedType.fun => ('Веселощі', AppColors.fun, Icons.celebration_rounded),
      NeedType.social => ('Соціум', AppColors.social, Icons.favorite_rounded),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        children: [
          Row(
            children: [
              const TomBackButton(),
              const SizedBox(width: 8),
              LevelBadge(level: age, progress: progress),
              const Spacer(),
              TomCurrencyBar(coins: coins, gems: gems),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 72,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (value / 100).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: Colors.white24,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating reaction text over the room (no emoji clutter).
class CareReactionBanner extends StatelessWidget {
  const CareReactionBanner({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        shadows: [Shadow(blurRadius: 10, color: Colors.black54)],
      ),
    );
  }
}
