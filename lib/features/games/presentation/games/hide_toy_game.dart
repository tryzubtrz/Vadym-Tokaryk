import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'game_scaffold.dart';

class HideToyGame extends StatefulWidget {
  const HideToyGame({super.key});

  @override
  State<HideToyGame> createState() => _HideToyGameState();
}

class _HideToyGameState extends State<HideToyGame> {
  late int _hidden;
  int? _picked;
  int _score = 0;
  int _round = 0;
  bool _showing = true;
  bool _ended = false;
  bool _won = false;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _nextRound();
  }

  Future<void> _nextRound() async {
    setState(() {
      _hidden = _rng.nextInt(3);
      _picked = null;
      _showing = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _showing = false);
  }

  void _pick(int i) {
    if (_showing || _ended || _picked != null) return;
    setState(() {
      _picked = i;
      if (i == _hidden) {
        _score += 25;
      }
      _round++;
    });
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      if (_round >= 5) {
        setState(() {
          _ended = true;
          _won = _score >= 75;
        });
      } else {
        _nextRound();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MiniGameScaffold(
      title: 'Сховай іграшку',
      score: _score,
      child: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _showing
                      ? 'Запамʼятай, де іграшка!'
                      : 'Де сховали іграшку? Раунд ${_round + 1}/5',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(3, (i) {
                    final reveal =
                        _showing || _picked != null && (_picked == i || _hidden == i);
                    return GestureDetector(
                      onTap: () => _pick(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 90,
                        height: 110,
                        decoration: BoxDecoration(
                          color: _picked == i
                              ? AppColors.brandPeach
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.brandCoral),
                        ),
                        child: Center(
                          child: Text(
                            reveal && i == _hidden
                                ? '🧸'
                                : reveal
                                    ? '📦'
                                    : '📦',
                            style: const TextStyle(fontSize: 40),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
          if (_ended)
            GameResultOverlay(
              won: _won,
              score: _score,
              onClose: () => Navigator.pop(context),
            ),
        ],
      ),
    );
  }
}
