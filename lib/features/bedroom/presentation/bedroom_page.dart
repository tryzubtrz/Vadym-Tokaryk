import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/character/animation/character_animator.dart';
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
  CharacterPose _pose = CharacterPose.idle;

  @override
  Widget build(BuildContext context) {
    final character = ref.watch(characterProvider);
    if (character == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const RoomSceneBackground(kind: RoomSceneKind.bedroom),
          if (_lightsOff)
            Container(color: Colors.black.withValues(alpha: 0.55)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  _back(context),
                  const SizedBox(width: 8),
                  LevelBadge(
                    level: character.age,
                    progress: character.yearProgress,
                  ),
                  const Spacer(),
                  TomCurrencyBar(
                    coins: character.coins,
                    gems: character.donateCoins,
                  ),
                ],
              ),
            ),
          ),
          if (_dream != null)
            Positioned(
              top: 100,
              left: 20,
              right: 20,
              child: Text(
                _dream!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                ),
              ).animate().fadeIn(),
            ),
          Align(
            alignment: const Alignment(0, 0.1),
            child: CharacterAnimator(
              character: character,
              size: MediaQuery.of(context).size.width * 0.72,
              pose: character.isSleeping ? CharacterPose.sleep : _pose,
            ),
          ),
          if (_nightLight)
            Positioned(
              right: 40,
              bottom: 160,
              child: const Icon(Icons.nightlight_round, size: 40, color: Color(0xFFFFE066))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.15, 1.15)),
            ),
          if (_lullaby)
            Positioned(
              left: 24,
              top: 120,
              child: const Text('🎵 ♪ ♫', style: TextStyle(fontSize: 28))
                  .animate(onPlay: (c) => c.repeat())
                  .moveX(begin: 0, end: 24, duration: 1600.ms),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 20,
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TomActionButton(
                    icon: _lightsOff ? Icons.lightbulb : Icons.lightbulb_outline,
                    color: const Color(0xFFFFC107),
                    onTap: () => setState(() => _lightsOff = !_lightsOff),
                  ),
                  TomActionButton(
                    icon: Icons.nightlight,
                    color: const Color(0xFF7E57C2),
                    selected: _nightLight,
                    onTap: () => setState(() => _nightLight = !_nightLight),
                  ),
                  TomActionButton(
                    icon: Icons.music_note,
                    color: const Color(0xFF26A69A),
                    selected: _lullaby,
                    onTap: () => setState(() => _lullaby = !_lullaby),
                  ),
                  TomActionButton(
                    icon: character.isSleeping
                        ? Icons.wb_sunny
                        : Icons.bedtime,
                    color: const Color(0xFFAB47BC),
                    onTap: () async {
                      if (!character.isSleeping) {
                        try {
                          await ref
                              .read(characterProvider.notifier)
                              .sleep(_lightsOff);
                          setState(() {
                            _pose = CharacterPose.sleep;
                            _dream = null;
                          });
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      } else {
                        await ref.read(characterProvider.notifier).wake();
                        setState(() {
                          _lightsOff = false;
                          _pose = CharacterPose.wave;
                          _dream = Random().nextBool()
                              ? '😴 Снилось, що ми стрибали на хмарах!'
                              : 'Доброго ранку! ☀️';
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _back(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.arrow_back, color: Colors.white),
      ),
    );
  }
}
