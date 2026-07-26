import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../features/character/animation/character_animator.dart';
import '../../../features/home/widgets/tom_style_ui.dart';
import '../../../shared/providers/app_providers.dart';

class BathroomPage extends ConsumerStatefulWidget {
  const BathroomPage({super.key});

  @override
  ConsumerState<BathroomPage> createState() => _BathroomPageState();
}

class _BathroomPageState extends ConsumerState<BathroomPage> {
  String? _moodText;
  CharacterPose _pose = CharacterPose.sit;

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
          const RoomSceneBackground(kind: RoomSceneKind.bathroom),
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
          if (_moodText != null)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  _moodText!,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black45)],
                  ),
                ).animate().fadeIn().then().fadeOut(delay: 900.ms),
              ),
            ),
          Align(
            alignment: const Alignment(0, 0.05),
            child: GestureDetector(
              onPanUpdate: (d) async {
                await ref
                    .read(characterProvider.notifier)
                    .wash(d.delta.distance * 0.08);
                setState(() {
                  _pose = CharacterPose.happy;
                  _moodText = 'Кехе! 🧼';
                });
              },
              child: CharacterAnimator(
                character: character,
                size: MediaQuery.of(context).size.width * 0.72,
                pose: _pose,
              ),
            ),
          ),
          // Water drops
          ...List.generate(5, (i) {
            return Positioned(
              top: 140.0 + i * 30,
              left: 60.0 + (i % 3) * 90,
              child: Icon(
                Icons.water_drop,
                color: AppColors.brandSky.withValues(alpha: 0.55),
                size: 18,
              )
                  .animate(onPlay: (c) => c.repeat())
                  .moveY(begin: 0, end: 50, duration: (800 + i * 100).ms)
                  .fadeOut(),
            );
          }),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TomActionButton(
                    icon: Icons.shower,
                    color: AppColors.brandSky,
                    onTap: () => setState(() {
                      _pose = CharacterPose.happy;
                      _moodText = 'Душ!';
                    }),
                  ),
                  TomActionButton(
                    icon: Icons.mood,
                    color: const Color(0xFF66BB6A),
                    onTap: () async {
                      await ref.read(characterProvider.notifier).brushTeeth();
                      setState(() => _moodText = 'Зубки! 😁');
                    },
                  ),
                  TomActionButton(
                    icon: Icons.content_cut,
                    color: const Color(0xFFFFA726),
                    onTap: () async {
                      await ref.read(characterProvider.notifier).comb();
                      setState(() => _moodText = 'Зачіска ✨');
                    },
                  ),
                  TomActionButton(
                    icon: Icons.wc,
                    color: const Color(0xFF8D6E63),
                    onTap: () async {
                      await ref.read(characterProvider.notifier).toilet();
                      setState(() {
                        _pose = CharacterPose.sit;
                        _moodText = 'Фух!';
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Text(
              'Мий пальцем по персонажу',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
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
