import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum RoomSceneKind {
  living,
  kitchen,
  bathroom,
  bedroom,
  classroom,
  games,
  closet,
}

/// Full-bleed cartoon room backdrop in Talking Tom style.
class RoomSceneBackground extends StatelessWidget {
  const RoomSceneBackground({
    super.key,
    required this.kind,
    this.child,
  });

  final RoomSceneKind kind;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RoomPainter(kind: kind),
      child: child,
    );
  }
}

class _RoomPainter extends CustomPainter {
  _RoomPainter({required this.kind});
  final RoomSceneKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case RoomSceneKind.kitchen:
        _kitchen(canvas, size);
      case RoomSceneKind.bathroom:
        _bathroom(canvas, size);
      case RoomSceneKind.bedroom:
        _bedroom(canvas, size);
      case RoomSceneKind.classroom:
        _classroom(canvas, size);
      case RoomSceneKind.games:
        _games(canvas, size);
      case RoomSceneKind.closet:
        _closet(canvas, size);
      case RoomSceneKind.living:
        _living(canvas, size);
    }
  }

  void _living(Canvas canvas, Size size) {
    // Soft pastel walls with tree wallpaper
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8F6FF), Color(0xFFD4F0E8), Color(0xFFB8E0C8)],
        ).createShader(Offset.zero & size),
    );
    // Wallpaper trees
    final tree = Paint()..color = const Color(0xFFB5D6C8).withValues(alpha: 0.55);
    for (var x = 20.0; x < size.width; x += 48) {
      for (var y = 40.0; y < size.height * 0.55; y += 56) {
        canvas.drawCircle(Offset(x, y), 10, tree);
        canvas.drawRect(
          Rect.fromCenter(center: Offset(x, y + 14), width: 4, height: 12),
          tree,
        );
      }
    }
    // Floor
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.72, size.width, size.height * 0.28),
      Paint()..color = const Color(0xFF8BCF7A),
    );
    // Window
    final win = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.62, size.height * 0.12, size.width * 0.28, size.height * 0.22),
      const Radius.circular(12),
    );
    canvas.drawRRect(win, Paint()..color = const Color(0xFF9AD4FF));
    canvas.drawRRect(
      win,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );
    // Picture frame
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.12, size.height * 0.1, 70, 80),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFFD4A017),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.12 + 8, size.height * 0.1 + 8, 54, 64),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFFFF0C8),
    );
  }

  void _kitchen(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF4E8), Color(0xFFFFE0C0), Color(0xFFE8B888)],
        ).createShader(Offset.zero & size),
    );
    // Curtains
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.08),
      Paint()..color = const Color(0xFFE85D4C),
    );
    // Window
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.2, size.height * 0.1, size.width * 0.6, size.height * 0.28),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFF87CEEB),
    );
    // Table
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.08, size.height * 0.68, size.width * 0.84, size.height * 0.2),
        const Radius.circular(16),
      ),
      Paint()..color = const Color(0xFFC45C3E),
    );
    // Food on table
    final foods = ['🍉', '🥞', '🥛', '🍩', '🍇'];
    for (var i = 0; i < foods.length; i++) {
      final tp = TextPainter(
        text: TextSpan(text: foods[i], style: const TextStyle(fontSize: 28)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(size.width * 0.14 + i * size.width * 0.15, size.height * 0.62),
      );
    }
  }

  void _bathroom(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFE3F6FF), Color(0xFFB8E4F5), Color(0xFF8EC8E0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Offset.zero & size),
    );
    // Tiles
    final tile = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 36) {
      for (var y = size.height * 0.35; y < size.height; y += 36) {
        canvas.drawRect(Rect.fromLTWH(x, y, 36, 36), tile);
      }
    }
    // Toilet
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * 0.72, size.height * 0.72),
          width: 70,
          height: 90,
        ),
        const Radius.circular(20),
      ),
      Paint()..color = Colors.white,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.72, size.height * 0.68),
        width: 40,
        height: 28,
      ),
      Paint()..color = const Color(0xFFB8E4F5),
    );
    // Door / window light
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.35, size.height * 0.08, size.width * 0.3, size.height * 0.28),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFFFFF4C8),
    );
  }

  void _bedroom(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFE8D4FF), Color(0xFFD0B8F0), Color(0xFFB898E0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Offset.zero & size),
    );
    // Bed
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.1, size.height * 0.58, size.width * 0.8, size.height * 0.28),
        const Radius.circular(24),
      ),
      Paint()..color = const Color(0xFF5B8DEF),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.14, size.height * 0.52, size.width * 0.72, size.height * 0.12),
        const Radius.circular(16),
      ),
      Paint()..color = const Color(0xFF7EB0FF),
    );
    // Stars on blanket
    final star = Paint()..color = const Color(0xFFFFE066);
    for (var i = 0; i < 8; i++) {
      final x = size.width * 0.2 + (i % 4) * size.width * 0.18;
      final y = size.height * 0.64 + (i ~/ 4) * 28;
      canvas.drawCircle(Offset(x, y), 5, star);
    }
    // Window moon glow
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.18),
      28,
      Paint()..color = const Color(0xFFFFF6C8).withValues(alpha: 0.85),
    );
  }

  void _classroom(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF5E6C8));
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.1, size.height * 0.08, size.width * 0.8, size.height * 0.38),
      Paint()..color = const Color(0xFF4A7A3A),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.7, size.width, size.height * 0.3),
      Paint()..color = const Color(0xFFE8C888),
    );
  }

  void _games(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFE8FFF4), Color(0xFFD4F0FF), Color(0xFFC8E8FF)],
        ).createShader(Offset.zero & size),
    );
    // Toys
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 0.75),
      22,
      Paint()..color = AppColors.brandCoral,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.7, size.height * 0.7, 50, 40),
        const Radius.circular(8),
      ),
      Paint()..color = AppColors.brandSun,
    );
  }

  void _closet(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFF8E8), Color(0xFFFFE8C8)],
        ).createShader(Offset.zero & size),
    );
    // Wardrobe
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.08, size.height * 0.08, size.width * 0.84, size.height * 0.55),
        const Radius.circular(12),
      ),
      Paint()..color = const Color(0xFFE8C888),
    );
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.08),
      Offset(size.width * 0.5, size.height * 0.63),
      Paint()
        ..color = const Color(0xFFD4A860)
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _RoomPainter old) => old.kind != kind;
}

/// Circular Talking-Tom style bottom action button.
class TomActionButton extends StatelessWidget {
  const TomActionButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
    this.selected = false,
    this.badge,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool selected;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: selected ? 58 : 52,
            height: selected ? 58 : 52,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          if (badge != null)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Purple level badge like Talking Tom.
class LevelBadge extends StatelessWidget {
  const LevelBadge({super.key, required this.level, this.progress = 0});

  final int level;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress.clamp(0.05, 1),
            strokeWidth: 4,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation(Color(0xFFE8B0FF)),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFB44DFF), Color(0xFF7B2CBF)],
              ),
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '$level',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gem + coin chips like Talking Tom top bar.
class TomCurrencyBar extends StatelessWidget {
  const TomCurrencyBar({
    super.key,
    required this.coins,
    required this.gems,
  });

  final int coins;
  final int gems;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _chip(const Color(0xFF5BC0EB), Icons.diamond, gems, true),
        const SizedBox(width: 8),
        _chip(const Color(0xFFF5C542), Icons.monetization_on, coins, true),
      ],
    );
  }

  Widget _chip(Color c, IconData icon, int value, bool plus) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          if (plus)
            const Icon(Icons.add_circle, color: Colors.lightGreenAccent, size: 16),
          if (plus) const SizedBox(width: 4),
          Icon(icon, color: c, size: 18),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Decorative floating birds / sparkles for living room energy.
class FloatingDecor extends StatelessWidget {
  const FloatingDecor({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _BirdsPainter(),
        size: Size.infinite,
      ),
    );
  }
}

class _BirdsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFFFE066);
    for (var i = 0; i < 4; i++) {
      final x = size.width * (0.25 + i * 0.15);
      final y = size.height * (0.35 + math.sin(i.toDouble()) * 0.05);
      // Simple bird shape
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: 22, height: 14),
        paint,
      );
      canvas.drawCircle(Offset(x + 8, y - 2), 5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
