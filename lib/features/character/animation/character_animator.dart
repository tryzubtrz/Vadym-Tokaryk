import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/models/character_model.dart';
import '../../../data/models/enums.dart';

/// Talking-Tom style anthropomorphic cat (Masya / Syryk).
/// Always breathing, blinking, reacting — never fully static.
class CharacterAnimator extends StatefulWidget {
  const CharacterAnimator({
    super.key,
    required this.character,
    this.size = 320,
    this.talking = false,
    this.reaction,
    this.pose = CharacterPose.idle,
    this.onTap,
    this.onStroke,
    this.onPoke,
    this.onShake,
  });

  final CharacterModel character;
  final double size;
  final bool talking;
  final InteractionGesture? reaction;
  final CharacterPose pose;
  final VoidCallback? onTap;
  final VoidCallback? onStroke;
  final VoidCallback? onPoke;
  final VoidCallback? onShake;

  @override
  State<CharacterAnimator> createState() => _CharacterAnimatorState();
}

enum CharacterPose { idle, happy, eat, sleep, sit, wave }

class _CharacterAnimatorState extends State<CharacterAnimator>
    with TickerProviderStateMixin {
  late final AnimationController _breathe;
  late final AnimationController _blink;
  late final AnimationController _idle;
  late final AnimationController _react;
  Offset _dragAccum = Offset.zero;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scheduleBlink();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _react = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  Future<void> _scheduleBlink() async {
    while (mounted) {
      await Future<void>.delayed(
        Duration(milliseconds: 1600 + math.Random().nextInt(2800)),
      );
      if (!mounted) return;
      await _blink.forward();
      await _blink.reverse();
    }
  }

  @override
  void didUpdateWidget(covariant CharacterAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reaction != null && widget.reaction != oldWidget.reaction) {
      _react.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _breathe.dispose();
    _blink.dispose();
    _idle.dispose();
    _react.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.onTap?.call();
        _react.forward(from: 0);
      },
      onLongPress: widget.onStroke,
      onDoubleTap: widget.onPoke,
      onPanUpdate: (d) {
        _dragAccum += d.delta;
        if (_dragAccum.distance > 40) {
          widget.onShake?.call();
          _dragAccum = Offset.zero;
          _react.forward(from: 0);
        }
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_breathe, _blink, _idle, _react]),
        builder: (_, __) {
          return CustomPaint(
            size: Size(widget.size, widget.size * 1.15),
            painter: _CatPainter(
              character: widget.character,
              breathe: _breathe.value,
              blink: _blink.value,
              idle: _idle.value,
              react: _react.value,
              talking: widget.talking,
              pose: widget.pose,
            ),
          );
        },
      ),
    );
  }
}

class _CatPainter extends CustomPainter {
  _CatPainter({
    required this.character,
    required this.breathe,
    required this.blink,
    required this.idle,
    required this.react,
    required this.talking,
    required this.pose,
  });

  final CharacterModel character;
  final double breathe;
  final double blink;
  final double idle;
  final double react;
  final bool talking;
  final CharacterPose pose;

  bool get _girl => character.type == CharacterType.masya;

  Color get _fur => _girl
      ? const Color(0xFFF2B86A) // cream-orange Masya
      : const Color(0xFFE59A4A); // ginger Syryk

  Color get _furDark => _girl
      ? const Color(0xFFE0943E)
      : const Color(0xFFC97830);

  Color get _muzzle => const Color(0xFFFFF3E0);

  Color get _eye =>
      _girl ? const Color(0xFF4CAF50) : const Color(0xFFC9A227);

  Color get _clothes =>
      _girl ? const Color(0xFFF0E6D8) : const Color(0xFF9AA3A8);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final scale = 1 + breathe * 0.025;
    final sway = (idle - 0.5) * 5;
    final bounce = math.sin(react * math.pi) * 10;

    canvas.save();
    canvas.translate(cx + sway * 0.25, h * 0.55 - bounce);
    canvas.scale(scale, 1 + breathe * 0.018);

    final bodyW = switch (character.bodyShape) {
      BodyShape.thin => w * 0.34,
      BodyShape.normal => w * 0.40,
      BodyShape.plump => w * 0.48,
    };

    // Soft ground shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, h * 0.42),
        width: bodyW * 1.35,
        height: 18,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.14),
    );

    // Tail
    final tail = Path()
      ..moveTo(bodyW * 0.35, h * 0.05)
      ..quadraticBezierTo(
        bodyW * 0.75 + sway,
        -h * 0.05,
        bodyW * 0.55 + sway * 0.5,
        -h * 0.22,
      );
    canvas.drawPath(
      tail,
      Paint()
        ..color = _fur
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.07
        ..strokeCap = StrokeCap.round,
    );

    // Legs
    final legPaint = Paint()..color = _fur;
    final legY = h * 0.28;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(-bodyW * 0.22, legY), width: w * 0.11, height: h * 0.22),
        const Radius.circular(20),
      ),
      legPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(bodyW * 0.22, legY), width: w * 0.11, height: h * 0.22),
        const Radius.circular(20),
      ),
      legPaint,
    );
    // Paws
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-bodyW * 0.22, legY + h * 0.1), width: w * 0.13, height: w * 0.08),
      Paint()..color = _muzzle,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bodyW * 0.22, legY + h * 0.1), width: w * 0.13, height: w * 0.08),
      Paint()..color = _muzzle,
    );

    // Body / hoodie-sweater
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, h * 0.02),
        width: bodyW,
        height: h * 0.42,
      ),
      Radius.circular(bodyW * 0.35),
    );
    canvas.drawRRect(bodyRect, Paint()..color = _clothes);

    // Hoodie pocket / sweater rib
    if (!_girl) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: const Offset(0, 18), width: 70, height: 28),
          const Radius.circular(12),
        ),
        Paint()..color = const Color(0xFF8A9398),
      );
      // Hood strings
      canvas.drawLine(
        const Offset(-18, -40),
        const Offset(-10, 0),
        Paint()
          ..color = Colors.white70
          ..strokeWidth = 2.5,
      );
      canvas.drawLine(
        const Offset(18, -40),
        const Offset(10, 0),
        Paint()
          ..color = Colors.white70
          ..strokeWidth = 2.5,
      );
    } else {
      canvas.drawLine(
        Offset(-bodyW * 0.35, h * 0.16),
        Offset(bodyW * 0.35, h * 0.16),
        Paint()
          ..color = const Color(0xFFE0D4C4)
          ..strokeWidth = 6,
      );
    }

    // Arms
    final armSwing = (idle - 0.5) * 14;
    final armPaint = Paint()
      ..color = _fur
      ..strokeWidth = w * 0.085
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final waveUp = pose == CharacterPose.wave || pose == CharacterPose.happy;
    canvas.drawLine(
      Offset(-bodyW * 0.42, -h * 0.05),
      Offset(-bodyW * 0.58, waveUp ? -h * 0.18 : h * 0.12 + armSwing),
      armPaint,
    );
    canvas.drawLine(
      Offset(bodyW * 0.42, -h * 0.05),
      Offset(bodyW * 0.58, h * 0.12 - armSwing),
      armPaint,
    );
    // Hand paws
    canvas.drawCircle(
      Offset(-bodyW * 0.58, waveUp ? -h * 0.18 : h * 0.12 + armSwing),
      w * 0.045,
      Paint()..color = _muzzle,
    );
    canvas.drawCircle(
      Offset(bodyW * 0.58, h * 0.12 - armSwing),
      w * 0.045,
      Paint()..color = _muzzle,
    );

    // Dirt overlay
    if (character.dirtLevel > 25) {
      canvas.drawRRect(
        bodyRect,
        Paint()
          ..color = const Color(0xFF6B4F3A).withValues(
            alpha: (character.dirtLevel / 180).clamp(0.05, 0.3),
          ),
      );
    }

    // Head
    final headR = w * 0.24;
    final headC = Offset(0, -h * 0.28);
    canvas.drawCircle(headC, headR, Paint()..color = _fur);

    // Tabby / cheek fluff
    if (!_girl) {
      final stripe = Paint()
        ..color = _furDark.withValues(alpha: 0.55)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      for (final dx in [-18.0, 0.0, 18.0]) {
        canvas.drawLine(
          headC.translate(dx, -headR * 0.55),
          headC.translate(dx * 0.6, -headR * 0.15),
          stripe,
        );
      }
    }

    // Ears
    _drawEar(canvas, headC.translate(-headR * 0.62, -headR * 0.78), true);
    _drawEar(canvas, headC.translate(headR * 0.62, -headR * 0.78), false);

    // Muzzle
    canvas.drawOval(
      Rect.fromCenter(
        center: headC.translate(0, headR * 0.28),
        width: headR * 1.15,
        height: headR * 0.85,
      ),
      Paint()..color = _muzzle,
    );

    // Eyes
    final eyeOpen = pose == CharacterPose.sleep ? 0.08 : (1 - blink);
    final eyeH = headR * 0.42 * eyeOpen + 1;
    _drawEye(canvas, headC.translate(-headR * 0.32, -headR * 0.05), eyeH);
    _drawEye(canvas, headC.translate(headR * 0.32, -headR * 0.05), eyeH);

    // Nose
    final nose = Path()
      ..moveTo(headC.dx, headC.dy + headR * 0.18)
      ..lineTo(headC.dx - 7, headC.dy + headR * 0.30)
      ..lineTo(headC.dx + 7, headC.dy + headR * 0.30)
      ..close();
    canvas.drawPath(nose, Paint()..color = const Color(0xFFE89A9A));

    // Mouth
    final mouthY = headC.dy + headR * 0.42;
    final mouthPaint = Paint()
      ..color = const Color(0xFF5A2A2A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    final talk = talking ? 6.0 + breathe * 6 : 0.0;
    if (pose == CharacterPose.sleep) {
      canvas.drawLine(
        Offset(headC.dx - 8, mouthY),
        Offset(headC.dx + 8, mouthY),
        mouthPaint,
      );
    } else if (character.mood < 35) {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(headC.dx, mouthY + 6), width: 22, height: 12),
        math.pi,
        math.pi,
        false,
        mouthPaint,
      );
    } else if (pose == CharacterPose.happy || pose == CharacterPose.eat || character.mood > 75) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(headC.dx, mouthY - 2),
          width: 28,
          height: 16 + talk,
        ),
        0.15,
        math.pi - 0.3,
        false,
        mouthPaint,
      );
      // Tongue peek
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(headC.dx, mouthY + 4 + talk * 0.2),
          width: 10,
          height: 8 + talk * 0.3,
        ),
        Paint()..color = const Color(0xFFFF7A8A),
      );
    } else {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(headC.dx, mouthY),
          width: 20,
          height: 8 + talk,
        ),
        0.2,
        math.pi - 0.4,
        false,
        mouthPaint,
      );
    }

    // Whiskers
    final whisker = Paint()
      ..color = Colors.black54
      ..strokeWidth = 1.4;
    for (final side in [-1.0, 1.0]) {
      for (final dy in [-4.0, 2.0, 8.0]) {
        canvas.drawLine(
          headC.translate(side * headR * 0.35, headR * 0.25 + dy),
          headC.translate(side * headR * 0.95, headR * 0.18 + dy * 1.2),
          whisker,
        );
      }
    }

    // Beard for senior Syryk
    if (character.hasBeard) {
      canvas.drawArc(
        Rect.fromCircle(
          center: headC.translate(0, headR * 0.55),
          radius: headR * 0.45,
        ),
        0.3,
        math.pi - 0.6,
        false,
        Paint()
          ..color = const Color(0xFF8B6914)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5,
      );
    }

    // Sleep Zzz
    if (character.isSleeping || pose == CharacterPose.sleep) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'Zzz',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 22 + breathe * 6,
            fontWeight: FontWeight.w900,
            shadows: const [Shadow(blurRadius: 4, color: Colors.black26)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(headR * 0.9, -h * 0.55));
    }

    canvas.restore();
  }

  void _drawEar(Canvas canvas, Offset tip, bool left) {
    final path = Path()
      ..moveTo(tip.dx + (left ? 18 : -18), tip.dy + 28)
      ..lineTo(tip.dx, tip.dy - 6)
      ..lineTo(tip.dx + (left ? -8 : 8), tip.dy + 30)
      ..close();
    canvas.drawPath(path, Paint()..color = _fur);
    final inner = Path()
      ..moveTo(tip.dx + (left ? 10 : -10), tip.dy + 24)
      ..lineTo(tip.dx, tip.dy + 4)
      ..lineTo(tip.dx + (left ? -2 : 2), tip.dy + 24)
      ..close();
    canvas.drawPath(inner, Paint()..color = const Color(0xFFFFC0CB));
  }

  void _drawEye(Canvas canvas, Offset c, double h) {
    canvas.drawOval(
      Rect.fromCenter(center: c, width: 22, height: h),
      Paint()..color = Colors.white,
    );
    if (h > 4) {
      canvas.drawCircle(c, 7, Paint()..color = _eye);
      canvas.drawCircle(c.translate(-2, -2), 2.5, Paint()..color = Colors.white);
      canvas.drawCircle(c, 3.2, Paint()..color = Colors.black87);
    }
  }

  @override
  bool shouldRepaint(covariant _CatPainter old) => true;
}
