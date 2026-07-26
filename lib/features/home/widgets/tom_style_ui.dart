import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/character_model.dart';
import '../../../data/models/enums.dart';

enum CharacterPose { idle, happy, eat, sleep, sit, wave, react }

enum RoomSceneKind {
  living,
  kitchen,
  bathroom,
  bedroom,
  classroom,
  games,
  closet,
}

String roomBackgroundAsset(RoomSceneKind kind) => switch (kind) {
      RoomSceneKind.kitchen => 'assets/images/rooms/bg_kitchen_empty.png',
      RoomSceneKind.bathroom => 'assets/images/rooms/bg_bath_empty.png',
      RoomSceneKind.bedroom => 'assets/images/rooms/bg_bed_empty.png',
      _ => 'assets/images/rooms/bg_living_empty.png',
    };

/// Talking Tom format:
/// 1) empty room background
/// 2) living character layered on top
/// 3) HUD / circular actions as overlay
class TomRoomStage extends StatelessWidget {
  const TomRoomStage({
    super.key,
    required this.kind,
    required this.character,
    this.pose = CharacterPose.idle,
    this.onCharacterTap,
    this.onStroke,
    this.onPoke,
    this.onShake,
    this.topBar,
    this.bottomBar,
    this.sideBar,
    this.overlay,
    this.characterAlignment = const Alignment(0, 0.35),
    this.characterSizeFactor = 0.78,
  });

  final RoomSceneKind kind;
  final CharacterModel character;
  final CharacterPose pose;
  final VoidCallback? onCharacterTap;
  final VoidCallback? onStroke;
  final VoidCallback? onPoke;
  final VoidCallback? onShake;
  final Widget? topBar;
  final Widget? bottomBar;
  final Widget? sideBar;
  final Widget? overlay;
  final Alignment characterAlignment;
  final double characterSizeFactor;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Room only
          Image.asset(
            roomBackgroundAsset(kind),
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
          ),

          // 2. Living character (not baked into room)
          Align(
            alignment: characterAlignment,
            child: CharacterAnimator(
              character: character,
              size: w * characterSizeFactor,
              pose: pose,
              onTap: onCharacterTap,
              onStroke: onStroke,
              onPoke: onPoke,
              onShake: onShake,
            ),
          ),

          // Readability vignette
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.22),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.28),
                  ],
                  stops: const [0, 0.16, 0.75, 1],
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

/// Cutout 3D character with continuous idle motion + pose swaps.
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
    with TickerProviderStateMixin {
  late final AnimationController _breathe;
  late final AnimationController _sway;
  CharacterPose _flashPose = CharacterPose.idle;
  bool _flashing = false;
  Offset _drag = Offset.zero;

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
  }

  @override
  void dispose() {
    _breathe.dispose();
    _sway.dispose();
    super.dispose();
  }

  CharacterPose get _effectivePose {
    if (_flashing) return _flashPose;
    if (widget.character.isSleeping) return CharacterPose.sleep;
    return widget.pose;
  }

  String _assetFor(CharacterPose pose) {
    final girl = widget.character.type == CharacterType.masya;
    if (!girl) return 'assets/images/character/syryk_idle_cut.png';
    return switch (pose) {
      CharacterPose.happy ||
      CharacterPose.wave ||
      CharacterPose.react =>
        'assets/images/character/masya_react_cut.png',
      CharacterPose.eat => 'assets/images/character/masya_eat_cut.png',
      CharacterPose.sleep => 'assets/images/character/masya_sleep_cut.png',
      CharacterPose.sit => 'assets/images/character/masya_stand_cut.png',
      _ => 'assets/images/character/masya_stand_cut.png',
    };
  }

  Future<void> _flash(CharacterPose pose) async {
    setState(() {
      _flashing = true;
      _flashPose = pose;
    });
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() => _flashing = false);
  }

  @override
  Widget build(BuildContext context) {
    final pose = _effectivePose;
    final asset = _assetFor(pose);

    return GestureDetector(
      onTap: () {
        widget.onTap?.call();
        _flash(CharacterPose.react);
      },
      onLongPress: () {
        widget.onStroke?.call();
        _flash(CharacterPose.happy);
      },
      onDoubleTap: () {
        widget.onPoke?.call();
        _flash(CharacterPose.react);
      },
      onPanUpdate: (d) {
        _drag += d.delta;
        if (_drag.distance > 42) {
          widget.onShake?.call();
          _drag = Offset.zero;
          _flash(CharacterPose.react);
        }
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_breathe, _sway]),
        builder: (_, __) {
          final breathe = 1 + _breathe.value * 0.035;
          final bob = (_breathe.value - 0.5) * 10;
          final sway = (_sway.value - 0.5) * 6;
          return Transform.translate(
            offset: Offset(sway, bob),
            child: Transform.scale(
              scale: breathe,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Image.asset(
                  asset,
                  key: ValueKey(asset),
                  width: widget.size,
                  height: widget.size * 1.05,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
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
            duration: const Duration(milliseconds: 160),
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
  const TomCurrencyBar({super.key, required this.coins, required this.gems});
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

class RoomSceneBackground extends StatelessWidget {
  const RoomSceneBackground({super.key, required this.kind, this.child});
  final RoomSceneKind kind;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(roomBackgroundAsset(kind), fit: BoxFit.cover),
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
