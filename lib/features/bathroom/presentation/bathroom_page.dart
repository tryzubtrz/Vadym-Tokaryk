import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
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
      characterAlignment: const Alignment(0, 0.25),
      onCharacterTap: () => setState(() => _pose = CharacterPose.react),
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
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: (d) async {
                await ref
                    .read(characterProvider.notifier)
                    .wash(d.delta.distance * 0.08);
                setState(() {
                  _pose = CharacterPose.happy;
                  _moodText = 'Кехе! 🧼';
                });
              },
            ),
          ),
          if (_moodText != null)
            Positioned(
              top: 110,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  _moodText!,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                  ),
                ).animate().fadeIn().then().fadeOut(delay: 900.ms),
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
    );
  }
}
