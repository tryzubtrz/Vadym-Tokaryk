import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';

/// STAGE 1 home stub with round action chips for route smoke-tests.
class HomeStubPage extends StatelessWidget {
  const HomeStubPage({super.key});

  static const _links = <(String, String, IconData, Color)>[
    ('/kitchen', 'Кухня', Icons.restaurant_rounded, AppColors.coral),
    ('/bathroom', 'Ванна', Icons.bathtub_rounded, AppColors.sky),
    ('/bedroom', 'Спальня', Icons.bed_rounded, AppColors.violet),
    ('/games', 'Ігри', Icons.sports_esports_rounded, AppColors.mint),
    ('/chat', 'Чат', Icons.chat_bubble_rounded, AppColors.sun),
    ('/photo', 'Фото', Icons.photo_camera_rounded, AppColors.peach),
    ('/code', 'Код', Icons.code_rounded, AppColors.ink),
    ('/friends', 'Друзі', Icons.people_alt_rounded, AppColors.sky),
    ('/settings', 'Налаштування', Icons.settings_rounded, AppColors.ink),
    ('/growth', 'Ріст', Icons.trending_up_rounded, AppColors.mint),
    ('/economy', 'Економіка', Icons.monetization_on_rounded, AppColors.sun),
    ('/auth', 'Автентифікація', Icons.person_rounded, AppColors.coral),
    ('/character', 'Персонаж', Icons.pets_rounded, AppColors.violet),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.appName)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            'STAGE 1 — каркас',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Навігація-заглушки. Логіка персонажа зʼявиться в STAGE 2–3.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.ink.withValues(alpha: 0.65),
                ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final item in _links)
                _RoundNavChip(
                  label: item.$2,
                  icon: item.$3,
                  color: item.$4,
                  onTap: () => context.push(item.$1),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundNavChip extends StatelessWidget {
  const _RoundNavChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: color.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
