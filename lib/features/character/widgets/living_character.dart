import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/character_model.dart';
import '../domain/enums.dart';

/// Idle-animated character placeholder (swap for Rive later).
class LivingCharacter extends StatefulWidget {
  const LivingCharacter({
    super.key,
    required this.character,
    this.size = 280,
    this.pose = CharacterPose.idle,
    this.onTap,
  });

  final CharacterModel character;
  final double size;
  final CharacterPose pose;
  final VoidCallback? onTap;

  @override
  State<LivingCharacter> createState() => _LivingCharacterState();
}

enum CharacterPose { idle, happy, eat, sleep, react }

class _LivingCharacterState extends State<LivingCharacter>
    with TickerProviderStateMixin {
  late final AnimationController _breathe;
  late final AnimationController _react;
  bool _flash = false;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);
    _react = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void dispose() {
    _breathe.dispose();
    _react.dispose();
    super.dispose();
  }

  String get _asset {
    final girl = widget.character.type == CharacterType.masya;
    if (!girl) return 'assets/images/character/syryk_idle_cut.png';
    final pose = _flash ? CharacterPose.react : widget.pose;
    if (widget.character.isSleeping || pose == CharacterPose.sleep) {
      return 'assets/images/character/masya_sleep_cut.png';
    }
    return switch (pose) {
      CharacterPose.eat => 'assets/images/character/masya_eat_cut.png',
      CharacterPose.happy || CharacterPose.react =>
        'assets/images/character/masya_react_cut.png',
      _ => 'assets/images/character/masya_stand_cut.png',
    };
  }

  Future<void> _handleTap() async {
    widget.onTap?.call();
    setState(() => _flash = true);
    await _react.forward(from: 0);
    await _react.reverse();
    if (mounted) setState(() => _flash = false);
  }

  @override
  Widget build(BuildContext context) {
    final border = switch (widget.character.bodyWeight) {
      BodyWeight.thin => AppColors.sky,
      BodyWeight.chubby => AppColors.coral,
      BodyWeight.normal => Colors.transparent,
    };

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_breathe, _react]),
        builder: (_, _) {
          final bob = (_breathe.value - 0.5) * 10;
          final scale = 1 + _breathe.value * 0.035 + _react.value * 0.08;
          final sway = math.sin(_breathe.value * math.pi) * 4;
          return Transform.translate(
            offset: Offset(sway, bob),
            child: Transform.scale(
              scale: scale,
              child: Container(
                decoration: BoxDecoration(
                  border: border == Colors.transparent
                      ? null
                      : Border.all(color: border, width: 4),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Image.asset(
                  _asset,
                  width: widget.size,
                  height: widget.size * 1.05,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => _FallbackBlob(
                    size: widget.size,
                    type: widget.character.type,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FallbackBlob extends StatelessWidget {
  const _FallbackBlob({required this.size, required this.type});
  final double size;
  final CharacterType type;

  @override
  Widget build(BuildContext context) {
    final color =
        type == CharacterType.masya ? AppColors.peach : AppColors.sky;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        type == CharacterType.masya ? '🐱' : '😺',
        style: TextStyle(fontSize: size * 0.35),
      ),
    );
  }
}
