import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/enums.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

final selectedCharacterTypeProvider =
    StateProvider<CharacterType>((ref) => CharacterType.masya);

class CharacterSelectPage extends ConsumerWidget {
  const CharacterSelectPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCharacterTypeProvider);

    return GradientScaffold(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Обери персонажа',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Сирик або Мася — старт з 4 років',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _Choice(
                      title: 'Сирик',
                      subtitle: 'Хлопчик',
                      emoji: '👦',
                      selected: selected == CharacterType.syryk,
                      color: AppColors.brandSky,
                      onTap: () => ref
                          .read(selectedCharacterTypeProvider.notifier)
                          .state = CharacterType.syryk,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _Choice(
                      title: 'Мася',
                      subtitle: 'Дівчинка',
                      emoji: '👧',
                      selected: selected == CharacterType.masya,
                      color: AppColors.brandCoral,
                      onTap: () => ref
                          .read(selectedCharacterTypeProvider.notifier)
                          .state = CharacterType.masya,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => context.go('/name'),
              child: const Text('Далі'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String emoji;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.2) : Colors.white70,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? color : Colors.transparent,
              width: 3,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 72)),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(subtitle),
            ],
          ),
        ),
      ),
    );
  }
}
