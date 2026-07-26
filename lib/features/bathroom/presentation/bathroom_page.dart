import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../character/providers/app_providers.dart';
import '../../character/widgets/living_character.dart';
import '../../growth/domain/care_helper.dart';

class BathroomPage extends ConsumerStatefulWidget {
  const BathroomPage({super.key});

  @override
  ConsumerState<BathroomPage> createState() => _BathroomPageState();
}

class _BathroomPageState extends ConsumerState<BathroomPage> {
  String? _mood;
  bool _washing = false;
  CharacterPose _pose = CharacterPose.idle;

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(characterProvider);
    if (c == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/rooms/bg_bath_empty.png',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                Container(decoration: const BoxDecoration(gradient: AppColors.bathroom)),
          ),
          Align(
            alignment: const Alignment(0, 0.1),
            child: LivingCharacter(
              character: c,
              size: MediaQuery.sizeOf(context).width * 0.66,
              pose: _pose,
            ),
          ),
          if (_washing)
            Positioned.fill(
              child: GestureDetector(
                onPanUpdate: (d) async {
                  await ref
                      .read(characterProvider.notifier)
                      .wash(d.delta.distance * 0.1);
                  setState(() {
                    _pose = CharacterPose.happy;
                    _mood = 'Кехе!';
                  });
                },
                onPanEnd: (_) => setState(() => _washing = false),
                child: Container(
                  color: AppColors.sky.withValues(alpha: 0.15),
                  alignment: const Alignment(0, -0.55),
                  child: const Text(
                    'Проведи пальцем — помий',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                    ),
                  ),
                ),
              ),
            ),
          if (_mood != null)
            Positioned(
              top: 120,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  _mood!,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                  ),
                ).animate().fadeIn().then().fadeOut(delay: 800.ms),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _back(context),
                  const SizedBox(width: 8),
                  Text(
                    'Ванна · чистота ${c.cleanliness.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black45)],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 20,
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _btn(Icons.shower, AppColors.sky, () async {
                    setState(() => _washing = true);
                    await ref.read(characterProvider.notifier).wash(20);
                    await awardCareIfNeeded(ref);
                    setState(() {
                      _pose = CharacterPose.happy;
                      _mood = 'Душ!';
                    });
                  }),
                  _btn(Icons.mood, AppColors.mint, () async {
                    await ref.read(characterProvider.notifier).brushTeeth();
                    await awardCareIfNeeded(ref);
                    setState(() => _mood = 'Зубки!');
                  }),
                  _btn(Icons.content_cut, AppColors.sun, () async {
                    await ref.read(characterProvider.notifier).comb();
                    setState(() {
                      _pose = CharacterPose.happy;
                      _mood = 'Зачіска!';
                    });
                  }),
                  _btn(Icons.wc, AppColors.toilet, () async {
                    await ref.read(characterProvider.notifier).toilet();
                    await awardCareIfNeeded(ref);
                    setState(() => _mood = 'Фух!');
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _back(BuildContext context) => GestureDetector(
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

  Widget _btn(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: Icon(icon, color: Colors.white),
        ),
      );
}
