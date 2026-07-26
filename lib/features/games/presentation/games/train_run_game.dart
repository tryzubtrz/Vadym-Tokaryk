import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'game_scaffold.dart';

/// Tap to jump across train cars.
class TrainRunGame extends StatefulWidget {
  const TrainRunGame({super.key});

  @override
  State<TrainRunGame> createState() => _TrainRunGameState();
}

class _TrainRunGameState extends State<TrainRunGame> {
  double _playerY = 0;
  double _velocity = 0;
  double _world = 0;
  int _score = 0;
  bool _ended = false;
  bool _won = false;
  Timer? _timer;
  final _gaps = <double>[];
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 12; i++) {
      _gaps.add(220.0 + i * 180 + _rng.nextDouble() * 40);
    }
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
  }

  void _tick() {
    if (_ended) return;
    setState(() {
      _world += 4;
      _velocity += 0.6;
      _playerY = (_playerY + _velocity).clamp(0, 200);
      if (_playerY >= 200 && _velocity > 0) {
        _velocity = 0;
        _playerY = 200;
      }
      _score = (_world / 20).floor();
      // Gap collision when on ground
      for (final g in _gaps) {
        final rel = g - _world;
        if (rel > 40 && rel < 90 && _playerY > 180) {
          _ended = true;
          _won = false;
        }
      }
      if (_world > 2000) {
        _ended = true;
        _won = true;
      }
    });
  }

  void _jump() {
    if (_playerY >= 195) _velocity = -12;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MiniGameScaffold(
      title: 'Біг по поїздах',
      score: _score,
      child: Stack(
        children: [
          GestureDetector(
            onTap: _jump,
            child: Container(
              color: const Color(0xFF87CEEB),
              child: CustomPaint(
                painter: _TrainPainter(world: _world, playerY: _playerY, gaps: _gaps),
                child: const Center(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Тап — стрибок між вагонами'),
                    ),
                  ),
                ),
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

class _TrainPainter extends CustomPainter {
  _TrainPainter({
    required this.world,
    required this.playerY,
    required this.gaps,
  });

  final double world;
  final double playerY;
  final List<double> gaps;

  @override
  void paint(Canvas canvas, Size size) {
    final groundY = size.height * 0.7;
    // Track
    canvas.drawRect(
      Rect.fromLTWH(0, groundY + 40, size.width, 8),
      Paint()..color = Colors.brown.shade700,
    );
    // Cars
    for (var x = -world % 160; x < size.width; x += 160) {
      final gapHere = gaps.any((g) {
        final rel = g - world;
        return (rel - x).abs() < 30;
      });
      if (gapHere) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, groundY - 30, 140, 70),
          const Radius.circular(8),
        ),
        Paint()..color = AppColors.brandCoral,
      );
    }
    // Player
    canvas.drawCircle(
      Offset(70, groundY - 50 - (200 - playerY) * 0.4),
      18,
      Paint()..color = AppColors.brandSun,
    );
  }

  @override
  bool shouldRepaint(covariant _TrainPainter old) => true;
}
