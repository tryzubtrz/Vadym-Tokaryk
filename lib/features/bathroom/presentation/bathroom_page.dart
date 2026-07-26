import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/enums.dart';
import '../../../features/character/domain/character_animation_state.dart';
import '../../../features/character/providers/character_animation_provider.dart';
import '../../../features/home/widgets/care_room_hud.dart';
import '../../../features/home/widgets/tom_style_ui.dart';
import '../../../shared/providers/app_providers.dart';

class BathroomPage extends ConsumerStatefulWidget {
  const BathroomPage({super.key});

  @override
  ConsumerState<BathroomPage> createState() => _BathroomPageState();
}

class _BathroomPageState extends ConsumerState<BathroomPage> {
  String? _moodText;
  CharacterPose _pose = CharacterPose.idle;
  bool _washing = false;

  Future<void> _showMood(String text, {CharacterPose? pose}) async {
    if (pose != null) {
      setState(() => _pose = pose);
      ref.read(characterAnimationProvider.notifier).setPose(pose.animPose);
    }
    setState(() => _moodText = text);
  }

  @override
  Widget build(BuildContext context) {
    final character = ref.watch(characterProvider);
    if (character == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return TomRoomStage(
      kind: RoomSceneKind.bathroom,
      character: character,
      pose: _pose,
      characterAlignment: const Alignment(0, 0.22),
      characterSizeFactor: 0.66,
      onCharacterTap: () => setState(() => _pose = CharacterPose.react),
      topBar: CareRoomHud(
        age: character.age,
        progress: character.yearProgress,
        coins: character.coins,
        gems: character.donateCoins,
        needs: character.needs,
        focusNeed: _pose == CharacterPose.sit
            ? NeedType.toilet
            : NeedType.cleanliness,
      ),
      overlay: Stack(
        children: [
          if (_washing)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) async {
                  await ref
                      .read(characterProvider.notifier)
                      .wash(d.delta.distance * 0.1);
                  await _showMood('Кехе!', pose: CharacterPose.happy);
                },
                onPanEnd: (_) => setState(() => _washing = false),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.brandSky.withValues(alpha: 0.12),
                  ),
                  child: const Align(
                    alignment: Alignment(0, -0.55),
                    child: Text(
                      'Проведи пальцем — помий',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_moodText != null)
            Positioned(
              top: 130,
              left: 16,
              right: 16,
              child: CareReactionBanner(text: _moodText!)
                  .animate()
                  .fadeIn()
                  .then()
                  .fadeOut(delay: 900.ms),
            ),
        ],
      ),
      bottomBar: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TomActionButton(
              icon: Icons.shower_rounded,
              color: AppColors.brandSky,
              selected: _washing,
              onTap: () async {
                setState(() => _washing = true);
                await ref.read(characterProvider.notifier).wash(18);
                await ref.read(growthDayProvider.notifier).tryAutoCare();
                await _showMood('Душ!', pose: CharacterPose.happy);
              },
            ),
            TomActionButton(
              icon: Icons.mood_rounded,
              color: const Color(0xFF66BB6A),
              onTap: () async {
                await ref.read(characterProvider.notifier).brushTeeth();
                await ref.read(growthDayProvider.notifier).tryAutoCare();
                await _showMood('Зубки!', pose: CharacterPose.happy);
              },
            ),
            TomActionButton(
              icon: Icons.content_cut_rounded,
              color: const Color(0xFFFFA726),
              onTap: () async {
                await ref.read(characterProvider.notifier).comb();
                await _showMood('Зачіска!', pose: CharacterPose.wave);
              },
            ),
            TomActionButton(
              icon: Icons.wc_rounded,
              color: const Color(0xFF8D6E63),
              onTap: () async {
                await ref.read(characterProvider.notifier).toilet();
                await ref.read(growthDayProvider.notifier).tryAutoCare();
                await _showMood('Фух!', pose: CharacterPose.sit);
                ref
                    .read(characterAnimationProvider.notifier)
                    .setPose(CharacterAnimPose.sit);
              },
            ),
          ],
        ),
      ),
    );
  }
}
