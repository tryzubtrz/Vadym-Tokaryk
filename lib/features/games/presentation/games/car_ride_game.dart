import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../../core/theme/app_colors.dart';
import 'game_scaffold.dart';

/// Steer by swipe (and tilt when available).
class CarRideGame extends StatefulWidget {
  const CarRideGame({super.key});

  @override
  State<CarRideGame> createState() => _CarRideGameState();
}

class _CarRideGameState extends State<CarRideGame> {
  double _x = 0.5;
  double _road = 0;
  int _score = 0;
  bool _ended = false;
  bool _won = false;
  final _obstacles = <Offset>[];
  Timer? _timer;
  StreamSubscription<AccelerometerEvent>? _accel;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 10; i++) {
      _obstacles.add(Offset(_rng.nextDouble(), 1.2 + i * 0.45));
    }
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
    try {
      _accel = accelerometerEventStream().listen((e) {
        setState(() => _x = (_x - e.x * 0.01).clamp(0.1, 0.9));
      });
    } catch (_) {}
  }

  void _tick() {
    if (_ended) return;
    setState(() {
      _road += 0.012;
      _score = (_road * 100).floor();
      for (final o in _obstacles) {
        final oy = o.dy - _road;
        if (oy > 0.75 && oy < 0.9 && (o.dx - _x).abs() < 0.12) {
          _ended = true;
          _won = false;
        }
      }
      if (_road > 5) {
        _ended = true;
        _won = true;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _accel?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MiniGameScaffold(
      title: 'Катання на машинці',
      score: _score,
      child: Stack(
        children: [
          GestureDetector(
            onHorizontalDragUpdate: (d) {
              setState(() {
                _x = (_x + d.delta.dx / MediaQuery.of(context).size.width)
                    .clamp(0.1, 0.9);
              });
            },
            child: Container(
              color: const Color(0xFF3A3A3A),
              child: CustomPaint(
                painter: _CarPainter(x: _x, road: _road, obstacles: _obstacles),
                size: Size.infinite,
                child: const Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Керуй свайпом або нахилом',
                      style: TextStyle(color: Colors.white),
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

class _CarPainter extends CustomPainter {
  _CarPainter({required this.x, required this.road, required this.obstacles});
  final double x;
  final double road;
  final List<Offset> obstacles;

  @override
  void paint(Canvas canvas, Size size) {
    // Road lines
    for (var i = 0; i < 8; i++) {
      final y = ((i * 80) - (road * 200) % 80);
      canvas.drawRect(
        Rect.fromLTWH(size.width / 2 - 4, y, 8, 40),
        Paint()..color = Colors.white54,
      );
    }
    for (final o in obstacles) {
      final oy = (o.dy - road) * size.height;
      if (oy < -40 || oy > size.height) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(o.dx * size.width, oy),
            width: 44,
            height: 44,
          ),
          const Radius.circular(8),
        ),
        Paint()..color = Colors.redAccent,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x * size.width, size.height * 0.82),
          width: 48,
          height: 72,
        ),
        const Radius.circular(10),
      ),
      Paint()..color = AppColors.brandSky,
    );
  }

  @override
  bool shouldRepaint(covariant _CarPainter old) => true;
}
