import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/character_model.dart';
import '../../../data/models/enums.dart';

/// Living character renderer (CustomPainter).
/// Designed to be swapped with Rive `.riv` assets when available —
/// same controller inputs: breathe, blink, mood, talk, react.
class CharacterAnimator extends StatefulWidget {
  const CharacterAnimator({
    super.key,
    required this.character,
    this.size = 280,
    this.talking = false,
    this.reaction,
    this.onTap,
    this.onStroke,
    this.onPoke,
    this.onShake,
  });

  final CharacterModel character;
  final double size;
  final bool talking;
  final InteractionGesture? reaction;
  final VoidCallback? onTap;
  final VoidCallback? onStroke;
  final VoidCallback? onPoke;
  final VoidCallback? onShake;

  @override
  State<CharacterAnimator> createState() => _CharacterAnimatorState();
}

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
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scheduleBlink();

    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    _react = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
  }

  void _scheduleBlink() async {
    while (mounted) {
      await Future<void>.delayed(
        Duration(milliseconds: 1800 + math.Random().nextInt(3200)),
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
        builder: (context, _) {
          return CustomPaint(
            size: Size.square(widget.size),
            painter: _CharacterPainter(
              character: widget.character,
              breathe: _breathe.value,
              blink: _blink.value,
              idle: _idle.value,
              react: _react.value,
              talking: widget.talking,
              reaction: widget.reaction,
            ),
          );
        },
      ),
    );
  }
}

class _CharacterPainter extends CustomPainter {
  _CharacterPainter({
    required this.character,
    required this.breathe,
    required this.blink,
    required this.idle,
    required this.react,
    required this.talking,
    required this.reaction,
  });

  final CharacterModel character;
  final double breathe;
  final double blink;
  final double idle;
  final double react;
  final bool talking;
  final InteractionGesture? reaction;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 10;
    final scale = 1 + breathe * 0.03;
    final sway = (idle - 0.5) * 6;
    final reactBounce = math.sin(react * math.pi) * 8;

    canvas.save();
    canvas.translate(cx + sway * 0.3, cy - reactBounce);
    canvas.scale(scale, 1 + breathe * 0.02);

    final isGirl = character.type == CharacterType.masya;
    final bodyColor = _bodyColor(isGirl);
    final bodyW = _bodyWidth();
    final bodyH = size.height * 0.42;

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, bodyH * 0.72),
        width: bodyW * 1.1,
        height: 18,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );

    // Body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, bodyH * 0.15), width: bodyW, height: bodyH),
      const Radius.circular(40),
    );
    canvas.drawRRect(bodyRect, Paint()..color = bodyColor);

    // Dirt overlay
    if (character.dirtLevel > 20) {
      canvas.drawRRect(
        bodyRect,
        Paint()
          ..color = const Color(0xFF6B4F3A)
              .withValues(alpha: (character.dirtLevel / 200).clamp(0.05, 0.35)),
      );
    }

    // Head
    final headR = size.width * 0.22;
    final headCenter = Offset(0, -bodyH * 0.28);
    canvas.drawCircle(headCenter, headR, Paint()..color = bodyColor);

    // Hair
    final hair = Paint()
      ..color = isGirl ? const Color(0xFF5A2E1F) : const Color(0xFF3B2A22);
    if (isGirl) {
      canvas.drawArc(
        Rect.fromCircle(center: headCenter.translate(0, -4), radius: headR + 4),
        math.pi,
        math.pi,
        false,
        hair..style = PaintingStyle.stroke
          ..strokeWidth = 14,
      );
      // Side hair
      canvas.drawOval(
        Rect.fromCenter(
          center: headCenter.translate(-headR * 0.85, headR * 0.3),
          width: 18,
          height: 40,
        ),
        hair..style = PaintingStyle.fill,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: headCenter.translate(headR * 0.85, headR * 0.3),
          width: 18,
          height: 40,
        ),
        hair,
      );
    } else {
      canvas.drawArc(
        Rect.fromCircle(center: headCenter.translate(0, -6), radius: headR + 2),
        math.pi * 1.05,
        math.pi * 0.9,
        true,
        hair..style = PaintingStyle.fill,
      );
      if (character.hasBeard) {
        canvas.drawArc(
          Rect.fromCircle(
            center: headCenter.translate(0, headR * 0.35),
            radius: headR * 0.55,
          ),
          0.2,
          math.pi - 0.4,
          false,
          Paint()
            ..color = const Color(0xFF4A3728)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6,
        );
      }
    }

    // Eyes
    final eyeY = headCenter.dy - 4;
    final eyeOpen = 1 - blink;
    final eyeH = 10.0 * eyeOpen + 1;
    _drawEye(canvas, Offset(headCenter.dx - 16, eyeY), eyeH);
    _drawEye(canvas, Offset(headCenter.dx + 16, eyeY), eyeH);

    // Mouth
    final mouthPaint = Paint()
      ..color = const Color(0xFF5A2A2A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final mouthY = headCenter.dy + headR * 0.35;
    final talkOpen = talking ? (0.5 + breathe * 0.5) * 8 : 0.0;
    if (character.isSleeping) {
      // zzz mouth soft
      canvas.drawLine(
        Offset(headCenter.dx - 8, mouthY),
        Offset(headCenter.dx + 8, mouthY),
        mouthPaint,
      );
    } else if (character.mood < 35) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(headCenter.dx, mouthY + 4),
          width: 22,
          height: 12,
        ),
        math.pi,
        math.pi,
        false,
        mouthPaint,
      );
    } else {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(headCenter.dx, mouthY - talkOpen * 0.2),
          width: 24,
          height: 10 + talkOpen,
        ),
        0.15,
        math.pi - 0.3,
        false,
        mouthPaint,
      );
    }

    // Cheeks
    if (character.mood > 60) {
      final cheek = Paint()
        ..color = AppColors.brandCoral.withValues(alpha: 0.35);
      canvas.drawCircle(
        headCenter.translate(-headR * 0.55, headR * 0.15),
        6,
        cheek,
      );
      canvas.drawCircle(
        headCenter.translate(headR * 0.55, headR * 0.15),
        6,
        cheek,
      );
    }

    // Arms sway
    final armPaint = Paint()
      ..color = bodyColor
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final armSwing = (idle - 0.5) * 12;
    canvas.drawLine(
      Offset(-bodyW * 0.42, -10),
      Offset(-bodyW * 0.55, 30 + armSwing),
      armPaint,
    );
    canvas.drawLine(
      Offset(bodyW * 0.42, -10),
      Offset(bodyW * 0.55, 30 - armSwing),
      armPaint,
    );

    // Age badge sparkle when young
    if (character.age < 10) {
      final spark = Paint()..color = AppColors.brandSun.withValues(alpha: 0.7);
      canvas.drawCircle(Offset(headR * 0.9, -bodyH * 0.5), 3 + breathe * 2, spark);
    }

    canvas.restore();

    // Sleep Zzz
    if (character.isSleeping) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'Zz',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 18 + breathe * 4,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width * 0.68, size.height * 0.18));
    }
  }

  void _drawEye(Canvas canvas, Offset c, double h) {
    canvas.drawOval(
      Rect.fromCenter(center: c, width: 12, height: h),
      Paint()..color = Colors.white,
    );
    if (h > 3) {
      canvas.drawCircle(
        c,
        3.5,
        Paint()..color = AppColors.brandInk,
      );
    }
  }

  double _bodyWidth() {
    return switch (character.bodyShape) {
      BodyShape.thin => 78,
      BodyShape.normal => 96,
      BodyShape.plump => 118,
    };
  }

  Color _bodyColor(bool girl) {
    // Age tint shifts slightly.
    if (character.stage == AgeStage.senior) {
      return girl ? const Color(0xFFE8B8A8) : const Color(0xFFD9B29C);
    }
    if (character.stage == AgeStage.child) {
      return girl ? const Color(0xFFFFC6B8) : const Color(0xFFFFD0B5);
    }
    return girl ? const Color(0xFFF2B8A4) : const Color(0xFFE8C0A8);
  }

  @override
  bool shouldRepaint(covariant _CharacterPainter old) => true;
}
