import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'game_scaffold.dart';

class MazeGame extends StatefulWidget {
  const MazeGame({super.key});

  @override
  State<MazeGame> createState() => _MazeGameState();
}

class _MazeGameState extends State<MazeGame> {
  // 0 path, 1 wall
  static const maze = [
    [0, 1, 0, 0, 0, 1, 0],
    [0, 1, 0, 1, 0, 1, 0],
    [0, 0, 0, 1, 0, 0, 0],
    [1, 1, 0, 1, 1, 1, 0],
    [0, 0, 0, 0, 0, 1, 0],
    [0, 1, 1, 1, 0, 1, 0],
    [0, 0, 0, 1, 0, 0, 0],
  ];

  int _r = 0;
  int _c = 0;
  int _moves = 0;
  bool _ended = false;
  bool _won = false;

  void _move(int dr, int dc) {
    if (_ended) return;
    final nr = _r + dr;
    final nc = _c + dc;
    if (nr < 0 || nc < 0 || nr >= maze.length || nc >= maze[0].length) return;
    if (maze[nr][nc] == 1) return;
    setState(() {
      _r = nr;
      _c = nc;
      _moves++;
      if (_r == maze.length - 1 && _c == maze[0].length - 1) {
        _ended = true;
        _won = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MiniGameScaffold(
      title: 'Лабіринт',
      score: (100 - _moves).clamp(0, 100),
      child: Stack(
        children: [
          Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Доведи персонажа до виходу ⭐'),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: maze[0].length,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: maze.length * maze[0].length,
                  itemBuilder: (context, i) {
                    final r = i ~/ maze[0].length;
                    final c = i % maze[0].length;
                    final wall = maze[r][c] == 1;
                    final here = r == _r && c == _c;
                    final goal =
                        r == maze.length - 1 && c == maze[0].length - 1;
                    return Container(
                      decoration: BoxDecoration(
                        color: wall
                            ? AppColors.brandInk
                            : goal
                                ? AppColors.brandSun
                                : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: here
                          ? const Center(
                              child: Text('😊', style: TextStyle(fontSize: 20)),
                            )
                          : null,
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  children: [
                    IconButton(
                      onPressed: () => _move(-1, 0),
                      icon: const Icon(Icons.keyboard_arrow_up, size: 40),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () => _move(0, -1),
                          icon: const Icon(Icons.keyboard_arrow_left, size: 40),
                        ),
                        const SizedBox(width: 40),
                        IconButton(
                          onPressed: () => _move(0, 1),
                          icon: const Icon(Icons.keyboard_arrow_right, size: 40),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => _move(1, 0),
                      icon: const Icon(Icons.keyboard_arrow_down, size: 40),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_ended)
            GameResultOverlay(
              won: _won,
              score: (100 - _moves).clamp(0, 100),
              onClose: () => Navigator.pop(context),
            ),
        ],
      ),
    );
  }
}
