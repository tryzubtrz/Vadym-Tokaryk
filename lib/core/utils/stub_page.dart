import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Temporary screen placeholder used by STAGE 1 routes.
class StubPage extends StatelessWidget {
  const StubPage({
    super.key,
    required this.title,
    this.subtitle = 'Заглушка STAGE 1 — екран зʼявиться в наступних етапах',
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.peach.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.coral.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.construction_rounded,
                  size: 40,
                  color: AppColors.coral,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.ink.withValues(alpha: 0.65),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
