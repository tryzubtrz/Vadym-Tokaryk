import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

/// Outfit / skins room — Talking Tom wardrobe layout (full logic in Step 9).
/// Step 1: UI scaffold only.
class WardrobePage extends StatelessWidget {
  const WardrobePage({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(title: const Text('Гардероб')),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            'Категорії одягу / аксесуарів',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                _sideCats(left: true),
                Expanded(
                  child: Center(
                    child: Container(
                      width: 200,
                      height: 260,
                      decoration: BoxDecoration(
                        color: AppColors.brandPeach.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.brandCoral),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Персонаж\n(Step 2: Rive)',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
                _sideCats(left: false),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Структура UI як у Talking Tom: персонаж по центру, '
              'круглі категорії зліва/справа, валюти зверху.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sideCats({required bool left}) {
    final icons = <IconData>[
      Icons.visibility,
      Icons.remove_red_eye_outlined,
      Icons.checkroom,
      Icons.watch,
      Icons.pets,
    ];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final icon in icons)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: CircleAvatar(
              backgroundColor:
                  left ? AppColors.brandPurple : AppColors.brandSky,
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
      ],
    );
  }
}
