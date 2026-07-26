import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'game_scaffold.dart';

class CloudJumpGame extends StatefulWidget {
  const CloudJumpGame({super.key});

  @override
  State<CloudJumpGame> createState() => _CloudJumpGameState();
}

class _CloudJumpGameState extends State<CloudJumpGame> {
  double _y = 400;
  double _vy = 0;
  double _x = 160;
  int _score = 0;
  bool _ended = false;
  bool _won = false;
  late List<Offset> _clouds;
  Timer? _timer;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _clouds = List.generate(
      8,
      (i) => Offset(40 + _rng.nextDouble() * 240, 500.0 - i * 90),
    );
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
  }

  void _tick() {
    if (_ended) return;
    setState(() {
      _vy += 0.35;
      _y += _vy;
      // Scroll world up when high
      if (_y < 280) {
        final dy = 280 - _y;
        _y = 280;
        for (var i = 0; i < _clouds.length; i++) {
          _clouds[i] = Offset(_clouds[i].dx, _clouds[i].dy + dy);
        }
        _score += (dy / 5).floor();
      }
      // Land on cloud
      if (_vy > 0) {
        for (final c in _clouds) {
          if ((_x - c.dx).abs() < 50 && _y > c.dy - 10 && _y < c.dy + 20) {
            _vy = -11;
            _y = c.dy - 10;
          }
        }
      }
      // Recycle clouds
      for (var i = 0; i < _clouds.length; i++) {
        if (_clouds[i].dy > 700) {
          _clouds[i] = Offset(40 + _rng.nextDouble() * 240, -40);
        }
      }
      if (_y > 720) {
        _ended = true;
        _won = false;
      }
      if (_score >= 120) {
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
    return MiniGameScaffold(
      title: 'Стрибки по хмарах',
      score: _score,
      child: Stack(
        children: [
          GestureDetector(
            onHorizontalDragUpdate: (d) =>
                setState(() => _x = (_x + d.delta.dx).clamp(20, 340)),
            child: Container(
              color: const Color(0xFFB8E4FF),
              child: Stack(
                children: [
                  for (final c in _clouds)
                    Positioned(
                      left: c.dx,
                      top: c.dy,
                      child: Container(
                        width: 90,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  Positioned(
                    left: _x,
                    top: _y,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.brandCoral,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: Text('Свайп ліворуч/праворуч', textAlign: TextAlign.center),
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
