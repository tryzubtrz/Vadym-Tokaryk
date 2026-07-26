import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/growth_balance.dart';
import '../../../core/theme/app_colors.dart';
import '../../character/providers/app_providers.dart';

class GamesPage extends ConsumerWidget {
  const GamesPage({super.key});

  static const games = <(String, String, IconData, Color)>[
    ('Біг по поїздах', 'train', Icons.train, AppColors.coral),
    ('Машинка', 'car', Icons.directions_car, AppColors.sky),
    ('Стрибки по хмарах', 'cloud', Icons.cloud, AppColors.mint),
    ('Ловля їжі', 'food', Icons.fastfood, AppColors.sun),
    ('Ритм', 'rhythm', Icons.music_note, AppColors.violet),
    ('Лабіринт', 'maze', Icons.grid_on, AppColors.ink),
    ('Піаніно', 'piano', Icons.piano, AppColors.peach),
    ('Памʼять', 'memory', Icons.psychology, AppColors.sky),
    ('Сховай іграшку', 'hide', Icons.toys, AppColors.coral),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ігри')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.15,
        ),
        itemCount: games.length,
        itemBuilder: (_, i) {
          final g = games[i];
          return Material(
            color: g.$4.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MiniGamePage(title: g.$1, id: g.$2),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(g.$3, size: 42, color: g.$4),
                  const SizedBox(height: 8),
                  Text(
                    g.$1,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class MiniGamePage extends ConsumerStatefulWidget {
  const MiniGamePage({super.key, required this.title, required this.id});
  final String title;
  final String id;

  @override
  ConsumerState<MiniGamePage> createState() => _MiniGamePageState();
}

class _MiniGamePageState extends ConsumerState<MiniGamePage> {
  int _score = 0;
  bool _ended = false;
  bool? _won;

  void _tap() {
    if (_ended) return;
    setState(() => _score += 1 + Random().nextInt(3));
    if (_score >= 20) _finish(true);
  }

  Future<void> _finish(bool won) async {
    setState(() {
      _ended = true;
      _won = won;
    });
    await ref.read(characterProvider.notifier).playFun(won ? 18 : 8);
    final xp =
        won ? GrowthBalance.miniGameWinXp : GrowthBalance.miniGamePlayXp;
    final coins = won ? 12 : 3;
    final msg =
        await ref.read(characterProvider.notifier).awardXp(xp, coins);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _ended
                    ? (_won == true ? 'Перемога!' : 'Кінець')
                    : 'Тапай швидко до 20 очок',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Рахунок: $_score',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 24),
              if (!_ended)
                ElevatedButton(
                  onPressed: _tap,
                  child: const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('ТАП!'),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Назад'),
                ),
              if (!_ended) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => _finish(false),
                  child: const Text('Здатися'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
