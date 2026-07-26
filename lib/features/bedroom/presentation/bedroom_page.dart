import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  Widget build(BuildContext context) {
    final character = ref.watch(characterProvider);
    if (character == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return TomRoomStage(
      kind: RoomSceneKind.bedroom,
      character: character,
      pose: CharacterPose.sleep,
      topBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            const TomBackButton(),
            const SizedBox(width: 8),
            LevelBadge(level: character.age, progress: character.yearProgress),
            const Spacer(),
            TomCurrencyBar(coins: character.coins, gems: character.donateCoins),
          ],
        ),
      ),
      overlay: Stack(
        children: [
          if (_lightsOff)
            IgnorePointer(
              child: Container(color: Colors.black.withValues(alpha: 0.45)),
            ),
          if (_dream != null)
            Positioned(
              top: 110,
              left: 20,
              right: 20,
              child: Text(
                _dream!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                ),
              ).animate().fadeIn(),
            ),
          if (_nightLight)
            const Positioned(
              right: 36,
              bottom: 160,
              child: Icon(Icons.nightlight_round, size: 40, color: Color(0xFFFFE066)),
            ),
          if (_lullaby)
            const Positioned(
              left: 24,
              top: 120,
              child: Text('🎵 ♪ ♫', style: TextStyle(fontSize: 28)),
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
              icon: character.isSleeping ? Icons.wb_sunny : Icons.bedtime,
              color: const Color(0xFFAB47BC),
              onTap: () async {
                if (!character.isSleeping) {
                  try {
                    await ref
                        .read(characterProvider.notifier)
                        .sleep(_lightsOff);
                    setState(() => _dream = null);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$e')),
                      );
                    }
                  }
                } else {
                  await ref.read(characterProvider.notifier).wake();
                  setState(() {
                    _lightsOff = false;
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
    );
  }
}
