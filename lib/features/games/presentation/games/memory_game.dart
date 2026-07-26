import 'dart:math';

import 'package:flutter/material.dart';

import 'game_scaffold.dart';

class MemoryGame extends StatefulWidget {
  const MemoryGame({super.key});

  @override
  State<MemoryGame> createState() => _MemoryGameState();
}

class _MemoryGameState extends State<MemoryGame> {
  late List<String> _cards;
  late List<bool> _revealed;
  late List<bool> _matched;
  int? _first;
  int _score = 0;
  int _moves = 0;
  bool _ended = false;
  bool _busy = false;

  static const _icons = ['🐶', '🐱', '🦊', '🐸', '🐼', '🐯'];

  @override
  void initState() {
    super.initState();
    final deck = [..._icons, ..._icons]..shuffle(Random());
    _cards = deck;
    _revealed = List.filled(deck.length, false);
    _matched = List.filled(deck.length, false);
  }

  Future<void> _tap(int i) async {
    if (_busy || _revealed[i] || _matched[i] || _ended) return;
    setState(() => _revealed[i] = true);
    if (_first == null) {
      _first = i;
      return;
    }
    _busy = true;
    _moves++;
    final a = _first!;
    if (_cards[a] == _cards[i]) {
      setState(() {
        _matched[a] = true;
        _matched[i] = true;
        _score += 20;
        _first = null;
      });
      if (_matched.every((e) => e)) {
        setState(() => _ended = true);
      }
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 550));
      setState(() {
        _revealed[a] = false;
        _revealed[i] = false;
        _first = null;
      });
    }
    _busy = false;
  }

  @override
  Widget build(BuildContext context) {
    return MiniGameScaffold(
      title: 'Гра на памʼять',
      score: _score,
      child: Stack(
        children: [
          Column(
            children: [
              Text('Ходи: $_moves'),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: _cards.length,
                  itemBuilder: (context, i) {
                    final show = _revealed[i] || _matched[i];
                    return GestureDetector(
                      onTap: () => _tap(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: _matched[i]
                              ? Colors.green.shade100
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Center(
                          child: Text(
                            show ? _cards[i] : '❓',
                            style: const TextStyle(fontSize: 32),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          if (_ended)
            GameResultOverlay(
              won: true,
              score: _score + (40 - _moves).clamp(0, 40),
              onClose: () => Navigator.pop(context),
            ),
        ],
      ),
    );
  }
}
