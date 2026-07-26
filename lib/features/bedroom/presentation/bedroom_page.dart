import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../character/providers/app_providers.dart';
import '../../character/widgets/living_character.dart';
import '../../growth/domain/care_helper.dart';

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
    final c = ref.watch(characterProvider);
    if (c == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/rooms/bg_bed_empty.png',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                Container(decoration: const BoxDecoration(gradient: AppColors.bedroom)),
          ),
          if (_lightsOff)
            IgnorePointer(
              child: Container(color: Colors.black.withValues(alpha: 0.45)),
            ),
          Align(
            alignment: const Alignment(0, 0.05),
            child: LivingCharacter(
              character: c,
              size: MediaQuery.sizeOf(context).width * 0.66,
              pose: c.isSleeping ? CharacterPose.sleep : CharacterPose.happy,
            ),
          ),
          if (_dream != null)
            Positioned(
              top: 120,
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
              bottom: 150,
              child: Icon(Icons.nightlight_round, size: 40, color: Color(0xFFFFE066)),
            ),
          if (_lullaby)
            const Positioned(
              left: 24,
              top: 120,
              child: Text('♪  ♫  ♪',
                  style: TextStyle(fontSize: 26, color: Colors.white)),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Спальня · енергія ${c.energy.toStringAsFixed(0)}%',
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
                  _btn(
                    _lightsOff ? Icons.lightbulb : Icons.lightbulb_outline,
                    const Color(0xFFFFC107),
                    () => setState(() => _lightsOff = !_lightsOff),
                  ),
                  _btn(
                    Icons.nightlight,
                    const Color(0xFF7E57C2),
                    () => setState(() => _nightLight = !_nightLight),
                  ),
                  _btn(
                    Icons.music_note,
                    const Color(0xFF26A69A),
                    () => setState(() => _lullaby = !_lullaby),
                  ),
                  _btn(
                    c.isSleeping ? Icons.wb_sunny : Icons.bedtime,
                    AppColors.violet,
                    () async {
                      if (!c.isSleeping) {
                        await ref.read(characterProvider.notifier).sleep();
                        await awardCareIfNeeded(ref);
                        setState(() {
                          _lightsOff = true;
                          _dream = null;
                        });
                      } else {
                        await ref.read(characterProvider.notifier).wake();
                        setState(() {
                          _lightsOff = false;
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
          ),
        ],
      ),
    );
  }

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
