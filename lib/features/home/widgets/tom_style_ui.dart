import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/character_model.dart';
import '../../character/domain/character_animation_state.dart';
import '../../character/providers/character_animation_provider.dart';
import '../../character/widgets/character_stage_view.dart';
import '../../character/widgets/rive_character_view.dart';

enum CharacterPose { idle, happy, eat, sleep, sit, wave, react }

extension CharacterPoseX on CharacterPose {
  CharacterAnimPose get animPose => switch (this) {
        CharacterPose.happy => CharacterAnimPose.happy,
        CharacterPose.eat => CharacterAnimPose.eat,
        CharacterPose.sleep => CharacterAnimPose.sleep,
        CharacterPose.sit => CharacterAnimPose.sit,
        CharacterPose.wave => CharacterAnimPose.wave,
        CharacterPose.react => CharacterAnimPose.react,
        CharacterPose.idle => CharacterAnimPose.idle,
      };
}

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
/// 2) living character layered on top (Rive or animated fallback)
/// 3) HUD / circular actions as overlay
class TomRoomStage extends ConsumerWidget {
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
    this.characterSizeFactor = 0.68,
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
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            roomBackgroundAsset(kind),
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
          ),
          CharacterStageView(
            character: character,
            widthFactor: characterSizeFactor,
            alignment: characterAlignment,
            pose: pose.animPose,
            onTap: onCharacterTap,
            onStroke: onStroke,
            onPoke: onPoke,
            onShake: onShake,
          ),
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
          ?overlay,
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

/// Compatibility wrapper — prefer [RiveCharacterView] / [CharacterStageView].
class CharacterAnimator extends ConsumerStatefulWidget {
  const CharacterAnimator({
    super.key,
    required this.character,
    this.size = 320,
    this.talking = false,
    this.pose = CharacterPose.idle,
    this.onTap,
    this.onStroke,
    this.onPoke,
    this.onShake,
  });

  final CharacterModel character;
  final double size;
  final bool talking;
  final CharacterPose pose;
  final VoidCallback? onTap;
  final VoidCallback? onStroke;
  final VoidCallback? onPoke;
  final VoidCallback? onShake;

  @override
  ConsumerState<CharacterAnimator> createState() => _CharacterAnimatorState();
}

class _CharacterAnimatorState extends ConsumerState<CharacterAnimator> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(covariant CharacterAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.talking != widget.talking ||
        oldWidget.pose != widget.pose ||
        oldWidget.character.isSleeping != widget.character.isSleeping) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    }
  }

  void _sync() {
    if (!mounted) return;
    final notifier = ref.read(characterAnimationProvider.notifier);
    notifier.setTalking(widget.talking);
    if (widget.character.isSleeping) {
      notifier.setPose(CharacterAnimPose.sleep);
    } else {
      notifier.setPose(widget.pose.animPose);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RiveCharacterView(
      character: widget.character,
      size: widget.size,
      onTap: widget.onTap,
      onStroke: widget.onStroke,
      onPoke: widget.onPoke,
      onShake: widget.onShake,
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
        ?child,
      ],
    );
  }
}

class FloatingDecor extends StatelessWidget {
  const FloatingDecor({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
