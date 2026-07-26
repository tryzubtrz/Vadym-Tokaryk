import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'game_scaffold.dart';

/// Falling notes — player taps keys, character "plays with paw".
class PianoGame extends StatefulWidget {
  const PianoGame({super.key});

  @override
  State<PianoGame> createState() => _PianoGameState();
}

class _PianoGameState extends State<PianoGame> {
  static const keys = ['C', 'D', 'E', 'F', 'G'];
  final _notes = <_PNote>[];
  int _score = 0;
  int _pawKey = -1;
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
      if (_rng.nextDouble() < 0.035) {
        _notes.add(_PNote(key: _rng.nextInt(keys.length), y: 0));
      }
      for (final n in _notes) {
        n.y += 3.5;
      }
      _notes.removeWhere((n) {
        if (n.y > 420) {
          return true;
        }
        return false;
      });
      if (_t > 40) {
        _ended = true;
        _won = _score >= 70;
      }
    });
  }

  void _press(int key) {
    setState(() => _pawKey = key);
    Future<void>.delayed(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _pawKey = -1);
    });
    _PNote? hit;
    for (final n in _notes) {
      if (n.key == key && n.y > 300 && n.y < 380) {
        hit = n;
        break;
      }
    }
    if (hit != null) {
      setState(() {
        _notes.remove(hit);
        _score += 12;
        if (_score >= 120) {
          _ended = true;
          _won = true;
        }
      });
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
      title: 'Піаніно',
      score: _score,
      child: Stack(
        children: [
          Column(
            children: [
              const Text('Ноти падають — тисни клавіші, персонаж грає лапкою'),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: List.generate(keys.length, (i) {
                    return Expanded(
                      child: Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            color: Colors.grey.shade200,
                          ),
                          for (final n in _notes.where((e) => e.key == i))
                            Positioned(
                              top: n.y,
                              left: 8,
                              right: 8,
                              child: Container(
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.brandMint,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(child: Text(keys[i])),
                              ),
                            ),
                          if (_pawKey == i)
                            const Align(
                              alignment: Alignment.bottomCenter,
                              child: Text('🐾', style: TextStyle(fontSize: 28)),
                            ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              Row(
                children: List.generate(keys.length, (i) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.brandInk,
                          minimumSize: const Size.fromHeight(64),
                        ),
                        onPressed: () => _press(i),
                        child: Text(keys[i]),
                      ),
                    ),
                  );
                }),
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

class _PNote {
  _PNote({required this.key, required this.y});
  final int key;
  double y;
}
