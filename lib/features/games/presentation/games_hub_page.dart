import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/enums.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import 'games/cloud_jump_game.dart';
import 'games/car_ride_game.dart';
import 'games/food_catch_game.dart';
import 'games/hide_toy_game.dart';
import 'games/maze_game.dart';
import 'games/memory_game.dart';
import 'games/piano_game.dart';
import 'games/rhythm_game.dart';
import 'games/train_run_game.dart';

class GamesHubPage extends ConsumerWidget {
  const GamesHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final games = <(MiniGameId, String, String, WidgetBuilder)>[
      (MiniGameId.trainRun, 'Біг по поїздах', '🚂', (_) => const TrainRunGame()),
      (MiniGameId.carRide, 'Катання на машинці', '🚗', (_) => const CarRideGame()),
      (MiniGameId.cloudJump, 'Стрибки по хмарах', '☁️', (_) => const CloudJumpGame()),
      (MiniGameId.foodCatch, 'Ловля їжі', '🍎', (_) => const FoodCatchGame()),
      (MiniGameId.rhythm, 'Ритм-гра', '🥁', (_) => const RhythmGame()),
      (MiniGameId.maze, 'Лабіринт', '🌀', (_) => const MazeGame()),
      (MiniGameId.piano, 'Піаніно', '🎹', (_) => const PianoGame()),
      (MiniGameId.memory, 'Гра на памʼять', '🧠', (_) => const MemoryGame()),
      (MiniGameId.hideToy, 'Сховай іграшку', '🧸', (_) => const HideToyGame()),
    ];

    return GradientScaffold(
      gradient: AppColors.gamesGradient,
      appBar: AppBar(
        title: const Text('Ігрова кімната'),
        actions: [
          IconButton(
            tooltip: 'Щоденний челендж',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Челендж дня: виграй у 3 різних іграх!'),
                ),
              );
            },
            icon: const Icon(Icons.flag_rounded),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Міні-ігри · спільні з друзями · тренування',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/friends'),
                  child: const Text('З друзями'),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.15,
              ),
              itemCount: games.length,
              itemBuilder: (context, i) {
                final g = games[i];
                return Material(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: g.$4),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(g.$3, style: const TextStyle(fontSize: 40)),
                          const SizedBox(height: 8),
                          Text(
                            g.$2,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
