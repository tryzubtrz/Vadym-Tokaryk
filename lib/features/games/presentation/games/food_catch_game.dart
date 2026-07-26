import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'game_scaffold.dart';

class FoodCatchGame extends StatefulWidget {
  const FoodCatchGame({super.key});

  @override
  State<FoodCatchGame> createState() => _FoodCatchGameState();
}

class _FoodCatchGameState extends State<FoodCatchGame> {
  double _basketX = 0.5;
  final _items = <_Falling>[];
  int _score = 0;
  int _misses = 0;
  bool _ended = false;
  bool _won = false;
  Timer? _timer;
  final _rng = Random();
  static const _emojis = ['🍎', '🍌', '🍇', '🥕', '🍪', '🪨'];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
  }

  void _tick() {
    if (_ended) return;
    setState(() {
      if (_rng.nextDouble() < 0.03) {
        _items.add(
          _Falling(
            x: _rng.nextDouble(),
            y: -0.05,
            emoji: _emojis[_rng.nextInt(_emojis.length)],
          ),
        );
      }
      for (final it in _items) {
        it.y += 0.012;
      }
      _items.removeWhere((it) {
        if (it.y > 0.85 && (it.x - _basketX).abs() < 0.12) {
          if (it.emoji == '🪨') {
            _misses += 2;
          } else {
            _score += 10;
          }
          return true;
        }
        if (it.y > 1.05) {
          if (it.emoji != '🪨') _misses++;
          return true;
        }
        return false;
      });
      if (_misses >= 5) {
        _ended = true;
        _won = false;
      }
      if (_score >= 100) {
        _ended = true;
        _won = true;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height - 120;
    return MiniGameScaffold(
      title: 'Ловля їжі',
      score: _score,
      child: Stack(
        children: [
          GestureDetector(
            onHorizontalDragUpdate: (d) {
              setState(() {
                _basketX =
                    (_basketX + d.delta.dx / w).clamp(0.08, 0.92);
              });
            },
            child: Container(
              color: const Color(0xFFE8FFF0),
              child: Stack(
                children: [
                  for (final it in _items)
                    Positioned(
                      left: it.x * w - 16,
                      top: it.y * h,
                      child: Text(it.emoji, style: const TextStyle(fontSize: 32)),
                    ),
                  Positioned(
                    left: _basketX * w - 36,
                    top: h * 0.88,
                    child: const Text('🧺', style: TextStyle(fontSize: 48)),
                  ),
                  Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: Text(
                      'Промахи: $_misses/5  (уникай 🪨)',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
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

class _Falling {
  _Falling({required this.x, required this.y, required this.emoji});
  double x;
  double y;
  final String emoji;
}
