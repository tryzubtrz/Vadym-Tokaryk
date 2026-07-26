import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/enums.dart';
import '../../../features/character/domain/character_animation_state.dart';
import '../../../features/character/providers/character_animation_provider.dart';
import '../../../features/home/widgets/care_room_hud.dart';
import '../../../features/home/widgets/tom_style_ui.dart';
import '../../../shared/providers/app_providers.dart';

class BedroomPage extends ConsumerStatefulWidget {
  const BedroomPage({super.key});

  @override
  ConsumerState<BedroomPage> createState() => _BedroomPageState();
}

class _BedroomPageState extends ConsumerState<BedroomPage> {
  bool _lightsOff = false;
  bool _nightLight = true;
  bool _lullaby = false;
  String? _dream;
  CharacterPose _pose = CharacterPose.happy;

  @override
  Widget build(BuildContext context) {
    final character = ref.watch(characterProvider);
    if (character == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final sleeping = character.isSleeping;

    return TomRoomStage(
      kind: RoomSceneKind.bedroom,
      character: character,
      pose: sleeping ? CharacterPose.sleep : _pose,
      characterAlignment: const Alignment(0, 0.1),
      characterSizeFactor: 0.66,
      topBar: CareRoomHud(
        age: character.age,
        progress: character.yearProgress,
        coins: character.coins,
        gems: character.donateCoins,
        needs: character.needs,
        focusNeed: NeedType.energy,
      ),
      overlay: Stack(
        children: [
          if (_lightsOff)
            IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                color: Colors.black.withValues(alpha: sleeping ? 0.55 : 0.4),
              ),
            ),
          if (_dream != null)
            Positioned(
              top: 130,
              left: 20,
              right: 20,
              child: CareReactionBanner(text: _dream!).animate().fadeIn(),
            ),
          if (_nightLight)
            Positioned(
              right: 36,
              bottom: 160,
              child: Icon(
                Icons.nightlight_round,
                size: 40,
                color: Color(0xFFFFE066).withValues(alpha: 0.95),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    begin: const Offset(0.92, 0.92),
                    end: const Offset(1.05, 1.05),
                    duration: 1400.ms,
                  ),
            ),
          if (_lullaby)
            const Positioned(
              left: 24,
              top: 120,
              child: Text(
                '♪  ♫  ♪',
                style: TextStyle(
                  fontSize: 26,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                ),
              ),
            ),
        ],
      ),
      bottomBar: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TomActionButton(
              icon: _lightsOff ? Icons.lightbulb : Icons.lightbulb_outline,
              color: const Color(0xFFFFC107),
              selected: !_lightsOff,
              onTap: () => setState(() => _lightsOff = !_lightsOff),
            ),
            TomActionButton(
              icon: Icons.nightlight_round,
              color: const Color(0xFF7E57C2),
              selected: _nightLight,
              onTap: () => setState(() => _nightLight = !_nightLight),
            ),
            TomActionButton(
              icon: Icons.music_note_rounded,
              color: const Color(0xFF26A69A),
              selected: _lullaby,
              onTap: () => setState(() => _lullaby = !_lullaby),
            ),
            TomActionButton(
              icon: sleeping ? Icons.wb_sunny_rounded : Icons.bedtime_rounded,
              color: const Color(0xFFAB47BC),
              onTap: () async {
                if (!sleeping) {
                  try {
                    await ref
                        .read(characterProvider.notifier)
                        .sleep(_lightsOff);
                    ref
                        .read(characterAnimationProvider.notifier)
                        .setPose(CharacterAnimPose.sleep);
                    setState(() {
                      _pose = CharacterPose.sleep;
                      _dream = null;
                      _lightsOff = true;
                    });
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$e')),
                      );
                    }
                  }
                } else {
                  await ref.read(characterProvider.notifier).wake();
                  ref
                      .read(characterAnimationProvider.notifier)
                      .setPose(CharacterAnimPose.wave);
                  setState(() {
                    _lightsOff = false;
                    _pose = CharacterPose.wave;
                    _dream = Random().nextBool()
                        ? 'Снилось, що ми стрибали на хмарах!'
                        : 'Доброго ранку!';
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
