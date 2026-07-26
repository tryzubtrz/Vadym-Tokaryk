import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/models/character_model.dart';
import '../../../data/models/enums.dart';
import '../domain/age_appearance.dart';
import '../domain/character_animation_state.dart';

/// Soft living sprite fallback used until stage `.riv` files are shipped.
/// Always breathes, sways, and can blink-scale — never a dead still frame.
class FallbackCharacterAnimator extends StatefulWidget {
  const FallbackCharacterAnimator({
    super.key,
    required this.character,
    required this.size,
    this.pose = CharacterAnimPose.idle,
    this.talking = false,
  });

  final CharacterModel character;
  final double size;
  final CharacterAnimPose pose;
  final bool talking;

  @override
  State<FallbackCharacterAnimator> createState() =>
      _FallbackCharacterAnimatorState();
}

class _FallbackCharacterAnimatorState extends State<FallbackCharacterAnimator>
    with TickerProviderStateMixin {
  late final AnimationController _breathe;
  late final AnimationController _sway;
  late final AnimationController _blink;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _sway = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scheduleBlink();
  }

  Future<void> _scheduleBlink() async {
    while (mounted) {
      await Future<void>.delayed(
        Duration(milliseconds: 1600 + math.Random().nextInt(2600)),
      );
      if (!mounted) return;
      await _blink.forward();
      await _blink.reverse();
    }
  }

  @override
  void dispose() {
    _breathe.dispose();
    _sway.dispose();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appearance = AgeAppearance.forAge(widget.character.age);
    final asset = appearance.fallbackSprite(
      widget.character.type,
      pose: widget.pose.spriteKey,
    );

    return AnimatedBuilder(
      animation: Listenable.merge([_breathe, _sway, _blink]),
      builder: (_, _) {
        final scale = 1 + _breathe.value * 0.04;
        final talkPulse = widget.talking ? 1 + _breathe.value * 0.02 : 1.0;
        final bob = (_breathe.value - 0.5) * 12;
        final sway = (_sway.value - 0.5) * 8;
        final blinkScaleY = 1 - _blink.value * 0.08;

        return Transform.translate(
          offset: Offset(sway, bob),
          child: Transform.scale(
            scale: scale * talkPulse,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(1.0, blinkScaleY, 1.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    asset,
                    width: widget.size,
                    height: widget.size * 1.05,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.pets,
                      size: widget.size * 0.4,
                      color: Colors.white70,
                    ),
                  ),
                  if (widget.character.dirtLevel > 30)
                    IgnorePointer(
                      child: Container(
                        width: widget.size * 0.55,
                        height: widget.size * 0.7,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B4F3A).withValues(
                            alpha: (widget.character.dirtLevel / 220)
                                .clamp(0.05, 0.28),
                          ),
                          borderRadius: BorderRadius.circular(40),
                        ),
                      ),
                    ),
                  if (widget.character.bodyShape == BodyShape.plump)
                    Positioned(
                      bottom: widget.size * 0.12,
                      child: Container(
                        width: widget.size * 0.5,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
