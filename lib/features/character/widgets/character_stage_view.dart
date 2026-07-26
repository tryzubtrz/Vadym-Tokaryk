import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/character_model.dart';
import '../../../data/models/enums.dart';
import '../domain/age_appearance.dart';
import '../domain/character_animation_state.dart';
import '../providers/character_animation_provider.dart';
import 'rive_character_view.dart';

/// Main on-screen character slot — targets 60–70% of viewport width (Tom UX).
class CharacterStageView extends ConsumerStatefulWidget {
  const CharacterStageView({
    super.key,
    required this.character,
    this.widthFactor = 0.68,
    this.alignment = const Alignment(0, 0.35),
    this.pose,
    this.showLabel = false,
    this.onTap,
    this.onStroke,
    this.onPoke,
    this.onShake,
  });

  final CharacterModel character;
  final double widthFactor;
  final Alignment alignment;
  final CharacterAnimPose? pose;
  final bool showLabel;
  final VoidCallback? onTap;
  final VoidCallback? onStroke;
  final VoidCallback? onPoke;
  final VoidCallback? onShake;

  @override
  ConsumerState<CharacterStageView> createState() => _CharacterStageViewState();
}

class _CharacterStageViewState extends ConsumerState<CharacterStageView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPose());
  }

  @override
  void didUpdateWidget(covariant CharacterStageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pose != widget.pose ||
        oldWidget.character.isSleeping != widget.character.isSleeping) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncPose());
    }
  }

  void _syncPose() {
    if (!mounted) return;
    final notifier = ref.read(characterAnimationProvider.notifier);
    if (widget.character.isSleeping) {
      notifier.setPose(CharacterAnimPose.sleep);
      return;
    }
    final pose = widget.pose;
    if (pose != null) {
      notifier.setPose(pose);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final appearance = AgeAppearance.forAge(widget.character.age);
    final size = w * widget.widthFactor * appearance.scale;

    return Align(
      alignment: widget.alignment,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RiveCharacterView(
            character: widget.character,
            size: size,
            onTap: widget.onTap,
            onStroke: widget.onStroke,
            onPoke: widget.onPoke,
            onShake: widget.onShake,
          ),
          if (widget.showLabel) ...[
            const SizedBox(height: 6),
            _StageChip(character: widget.character),
          ],
        ],
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.character});
  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final appearance = AgeAppearance.forAge(character.age);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '${character.name} · ${character.age}р · ${appearance.stage.labelUk}'
        '${character.hasBeard ? ' · борідка' : ''}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Convenience mapping from room pose name strings to animation poses.
CharacterAnimPose mapRoomPose(String? roomPose) {
  return switch (roomPose) {
    'happy' => CharacterAnimPose.happy,
    'eat' => CharacterAnimPose.eat,
    'sleep' => CharacterAnimPose.sleep,
    'sit' => CharacterAnimPose.sit,
    'wave' => CharacterAnimPose.wave,
    'react' => CharacterAnimPose.react,
    _ => CharacterAnimPose.idle,
  };
}
