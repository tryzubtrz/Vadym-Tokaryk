import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/services/character_service.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/currency_badge.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

class EconomyPage extends ConsumerWidget {
  const EconomyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(characterProvider);
    if (c == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return GradientScaffold(
      appBar: AppBar(title: const Text('Економіка')),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CurrencyBadge(coins: c.coins, donateCoins: c.donateCoins),
            const SizedBox(height: 16),
            Text(
              'Звичайні коїни — за догляд, ігри, завдання, відео.\n'
              'Донатні коїни — за реальні гроші (кнопка поки неактивна).\n'
              'Донатні можна обміняти на звичайні (1 → 50) або витратити на косметику/моделі.\n'
              'Основний розвиток персонажа — безкоштовно.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: null,
              child: const Text('Донат (скоро)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: c.donateCoins <= 0
                  ? null
                  : () async {
                      await ref
                          .read(characterServiceProvider)
                          .exchangeDonateToRegular(1);
                      await ref.read(characterProvider.notifier).refresh();
                    },
              child: const Text('Обміняти 1 донатний → 50 звичайних'),
            ),
            const SizedBox(height: 24),
            // Dev helper to test economy
            TextButton(
              onPressed: () async {
                await ref.read(characterServiceProvider).addCoins(50, donate: 1);
                await ref.read(characterProvider.notifier).refresh();
              },
              child: Text(
                'Dev: +50 коїнів / +1 донат',
                style: TextStyle(
                  color: AppColors.brandInk.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
