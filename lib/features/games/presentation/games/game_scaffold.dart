import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/services/growth_service.dart';
import '../../../../shared/providers/app_providers.dart';

class GameResultOverlay extends ConsumerStatefulWidget {
  const GameResultOverlay({
    super.key,
    required this.won,
    required this.score,
    required this.onClose,
  });

  final bool won;
  final int score;
  final VoidCallback onClose;

  @override
  ConsumerState<GameResultOverlay> createState() => _GameResultOverlayState();
}

class _GameResultOverlayState extends ConsumerState<GameResultOverlay> {
  late final ConfettiController _confetti;
  String? _reward;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ev = await ref
          .read(growthServiceProvider)
          .awardMiniGame(won: widget.won);
      await ref.read(characterProvider.notifier).refresh();
      setState(() {
        _reward = '+${ev.xpGained} XP · +${ev.coinsGained} коїнів';
      });
      if (widget.won) _confetti.play();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ModalBarrier(color: Colors.black54, dismissible: false),
        ConfettiWidget(
          confettiController: _confetti,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
        ),
        Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.won ? 'Перемога! 🎉' : 'Спробуй ще 💪',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text('Рахунок: ${widget.score}'),
              if (_reward != null) ...[
                const SizedBox(height: 8),
                Text(
                  _reward!,
                  style: const TextStyle(
                    color: AppColors.brandCoral,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: widget.onClose,
                child: const Text('Далі'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MiniGameScaffold extends StatelessWidget {
  const MiniGameScaffold({
    super.key,
    required this.title,
    required this.child,
    this.score = 0,
    this.trailing,
  });

  final String title;
  final Widget child;
  final int score;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '⭐ $score',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
      body: child,
    );
  }
}
