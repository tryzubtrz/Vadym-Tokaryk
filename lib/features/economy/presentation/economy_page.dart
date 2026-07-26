import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../character/providers/app_providers.dart';

class EconomyPage extends ConsumerWidget {
  const EconomyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(characterProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Економіка')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _card(
              'Звичайні коїни',
              '${c?.regularCoins ?? 0}',
              AppColors.sun,
              Icons.monetization_on,
            ),
            const SizedBox(height: 12),
            _card(
              'Донат-коїни',
              '${c?.donateCoins ?? 0}',
              AppColors.sky,
              Icons.diamond,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: null,
              child: const Text('Купити донат-коїни (неактивно)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                if (c == null) return;
                await ref
                    .read(characterProvider.notifier)
                    .awardXp(25, 10);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('+25 XP за відео-нагороди (stub)')),
                  );
                }
              },
              child: const Text('Подивитись відео за нагороду'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                value,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
