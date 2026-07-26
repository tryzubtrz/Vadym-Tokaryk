import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'game_scaffold.dart';

class RhythmGame extends StatefulWidget {
  const RhythmGame({super.key});

  @override
  State<RhythmGame> createState() => _RhythmGameState();
}

class _RhythmGameState extends State<RhythmGame> {
  final _notes = <_Note>[];
  int _score = 0;
  int _combo = 0;
  bool _ended = false;
  bool _won = false;
  Timer? _timer;
  final _rng = Random();
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
  }

  void _tick() {
    if (_ended) return;
    setState(() {
      _t += 0.016;
      if (_rng.nextDouble() < 0.04) {
        _notes.add(_Note(lane: _rng.nextInt(4), y: -0.05));
      }
      for (final n in _notes) {
        n.y += 0.014;
      }
      _notes.removeWhere((n) {
        if (n.y > 1.05) {
          _combo = 0;
          return true;
        }
        return false;
      });
      if (_t > 45) {
        _ended = true;
        _won = _score >= 80;
      }
    });
  }

  void _hit(int lane) {
    _Note? hit;
    for (final n in _notes) {
      if (n.lane == lane && n.y > 0.75 && n.y < 0.95) {
        hit = n;
        break;
      }
    }
    if (hit != null) {
      setState(() {
        _notes.remove(hit);
        _combo++;
        _score += 10 + _combo;
        if (_score >= 150) {
          _ended = true;
          _won = true;
        }
      });
    } else {
      setState(() => _combo = 0);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MiniGameScaffold(
      title: 'Ритм-гра',
      score: _score,
      child: Stack(
        children: [
          Column(
            children: [
              Text('Комбо: $_combo'),
              Expanded(
                child: Row(
                  children: List.generate(4, (lane) {
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => _hit(lane),
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          color: Colors.black12,
                          child: Stack(
                            children: [
                              for (final n in _notes.where((e) => e.lane == lane))
                                Align(
                                  alignment: Alignment(0, -1 + 2 * n.y),
                                  child: Container(
                                    width: 48,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: AppColors.brandCoral,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              Align(
                                alignment: const Alignment(0, 0.8),
                                child: Container(
                                  height: 4,
                                  color: AppColors.brandSun,
                                ),
                              ),
                            ],
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

class _Note {
  _Note({required this.lane, required this.y});
  final int lane;
  double y;
}
