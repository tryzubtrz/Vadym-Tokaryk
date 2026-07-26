import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class CurrencyBadge extends StatelessWidget {
  const CurrencyBadge({
    super.key,
    required this.coins,
    required this.donateCoins,
  });

  final int coins;
  final int donateCoins;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pill(
          icon: Icons.monetization_on_rounded,
          color: AppColors.coins,
          value: coins,
        ),
        const SizedBox(width: 8),
        _pill(
          icon: Icons.diamond_rounded,
          color: AppColors.donateCoins,
          value: donateCoins,
        ),
      ],
    );
  }

  Widget _pill({
    required IconData icon,
    required Color color,
    required int value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
