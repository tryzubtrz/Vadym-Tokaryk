import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class ProgressYearBar extends StatelessWidget {
  const ProgressYearBar({
    super.key,
    required this.progress,
    required this.age,
    required this.iq,
  });

  final double progress;
  final int age;
  final int iq;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$age років',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'IQ $iq',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.brandSky,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 12,
            backgroundColor: AppColors.brandSky.withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation(AppColors.brandCoral),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'До ${age + 1} року: ${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
