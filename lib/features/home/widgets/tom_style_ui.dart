import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/character_model.dart';
import '../../../data/models/enums.dart';

enum CharacterPose { idle, happy, eat, sleep, sit, wave }

enum RoomSceneKind {
  living,
  kitchen,
  bathroom,
  bedroom,
  classroom,
  games,
  closet,
}

/// Full-bleed 3D rendered room scene (Talking Tom quality assets).
class TomRoomStage extends StatelessWidget {
  const TomRoomStage({
    super.key,
    required this.kind,
    this.character,
    this.pose = CharacterPose.idle,
    this.onCharacterTap,
    this.topBar,
    this.bottomBar,
    this.sideBar,
    this.overlay,
  });

  final RoomSceneKind kind;
  final CharacterModel? character;
  final CharacterPose pose;
  final VoidCallback? onCharacterTap;
  final Widget? topBar;
  final Widget? bottomBar;
  final Widget? sideBar;
  final Widget? overlay;

  String get _roomAsset => switch (kind) {
        RoomSceneKind.kitchen => 'assets/images/rooms/room_kitchen_masya.png',
        RoomSceneKind.bathroom => 'assets/images/rooms/room_bath_masya.png',
        RoomSceneKind.bedroom => 'assets/images/rooms/room_bed_masya.png',
        _ => 'assets/images/rooms/room_living_masya.png',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 3D room plate with subtle living motion
          GestureDetector(
            onTap: onCharacterTap,
            child: Image.asset(
              _roomAsset,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(1.0, 1.0),
                  end: const Offset(1.025, 1.025),
                  duration: 3200.ms,
                  curve: Curves.easeInOut,
                ),
          ),

          // Soft vignette for UI readability
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.35),
                  ],
                  stops: const [0, 0.18, 0.72, 1],
                ),
              ),
            ),
          ),

          if (overlay != null) overlay!,

          if (topBar != null)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: SafeArea(bottom: false, child: topBar!),
            ),

          if (sideBar != null)
            Positioned(
              right: 10,
              top: MediaQuery.of(context).size.height * 0.26,
              child: sideBar!,
            ),

          if (bottomBar != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(top: false, child: bottomBar!),
            ),
        ],
      ),
    );
  }
}

/// Floating 3D character sprite (cutout) for chat / games overlays.
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

class _CharacterAnimatorState extends State<CharacterAnimator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathe;
  Offset _drag = Offset.zero;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  String _assetFor() {
    final isGirl = widget.character.type == CharacterType.masya;
    if (!isGirl) {
      return 'assets/images/character/syryk_idle_cut.png';
    }
    return switch (widget.pose) {
      CharacterPose.happy || CharacterPose.wave =>
        'assets/images/character/masya_happy_cut.png',
      CharacterPose.eat => 'assets/images/character/masya_eat_cut.png',
      CharacterPose.sleep => 'assets/images/character/masya_sleep_cut.png',
      _ => 'assets/images/character/masya_idle_cut.png',
    };
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onStroke,
      onDoubleTap: widget.onPoke,
      onPanUpdate: (d) {
        _drag += d.delta;
        if (_drag.distance > 40) {
          widget.onShake?.call();
          _drag = Offset.zero;
        }
      },
      child: AnimatedBuilder(
        animation: _breathe,
        builder: (_, __) {
          final s = 1 + _breathe.value * 0.03;
          return Transform.translate(
            offset: Offset(0, (0.5 - _breathe.value) * 8),
            child: Transform.scale(
              scale: s,
              child: Image.asset(
                _assetFor(),
                width: widget.size,
                height: widget.size,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) => SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: const Icon(Icons.pets, size: 80),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

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
            width: selected ? 60 : 54,
            height: selected ? 60 : 54,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          if (badge != null)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LevelBadge extends StatelessWidget {
  const LevelBadge({super.key, required this.level, this.progress = 0});

  final int level;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
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
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFC85CFF), Color(0xFF7B2CBF)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
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
        _chip(const Color(0xFF5BC0EB), Icons.diamond, gems),
        const SizedBox(width: 8),
        _chip(const Color(0xFFF5C542), Icons.monetization_on, coins),
      ],
    );
  }

  Widget _chip(Color c, IconData icon, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.add_circle, color: Colors.lightGreenAccent, size: 16),
          const SizedBox(width: 4),
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

class TomBackButton extends StatelessWidget {
  const TomBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.maybePop(context),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
      ),
    );
  }
}

class TomSideFab extends StatelessWidget {
  const TomSideFab({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: Icon(icon, color: AppColors.brandInk),
      ),
    );
  }
}

/// Kept for older imports that referenced painted backgrounds.
class RoomSceneBackground extends StatelessWidget {
  const RoomSceneBackground({super.key, required this.kind, this.child});
  final RoomSceneKind kind;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final asset = switch (kind) {
      RoomSceneKind.kitchen => 'assets/images/rooms/room_kitchen_masya.png',
      RoomSceneKind.bathroom => 'assets/images/rooms/room_bath_masya.png',
      RoomSceneKind.bedroom => 'assets/images/rooms/room_bed_masya.png',
      _ => 'assets/images/rooms/room_living_masya.png',
    };
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(asset, fit: BoxFit.cover),
        if (child != null) child!,
      ],
    );
  }
}

class FloatingDecor extends StatelessWidget {
  const FloatingDecor({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
