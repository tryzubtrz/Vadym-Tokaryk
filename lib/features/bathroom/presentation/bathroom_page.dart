import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../features/character/animation/character_animator.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

class BathroomPage extends ConsumerStatefulWidget {
  const BathroomPage({super.key});

  @override
  ConsumerState<BathroomPage> createState() => _BathroomPageState();
}

class _BathroomPageState extends ConsumerState<BathroomPage> {
  double _washProgress = 0;
  String? _moodText;
  bool _inShower = true;

  @override
  Widget build(BuildContext context) {
    final character = ref.watch(characterProvider);
    if (character == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return GradientScaffold(
      gradient: AppColors.bathGradient,
      appBar: AppBar(title: Text(_inShower ? 'Душ' : 'Ванна')),
      child: Column(
        children: [
          Text(
            'Чистота: ${character.needs.cleanliness.toStringAsFixed(0)}% · '
            'Бруд: ${character.dirtLevel.toStringAsFixed(0)}%',
          ),
          if (_moodText != null)
            Text(
              _moodText!,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppColors.brandSky,
              ),
            ).animate().fadeIn().then().fadeOut(delay: 800.ms),
          Expanded(
            child: GestureDetector(
              onPanUpdate: (d) async {
                setState(() {
                  _washProgress =
                      (_washProgress + d.delta.distance * 0.15).clamp(0, 100);
                });
                if (_washProgress > 8) {
                  await ref
                      .read(characterProvider.notifier)
                      .wash(d.delta.distance * 0.08);
                  setState(() {
                    _moodText = character.mood > 40 ? 'Кехе-хе! Приємно 🧼' : 'Ей! Холодно…';
                    _washProgress = 0;
                  });
                }
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 260,
                    height: 320,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(_inShower ? 40 : 80),
                      border: Border.all(
                        color: AppColors.brandSky.withValues(alpha: 0.5),
                        width: 3,
                      ),
                    ),
                  ),
                  CharacterAnimator(character: character, size: 220),
                  // Water droplets
                  ...List.generate(6, (i) {
                    return Positioned(
                      top: 40.0 + i * 18,
                      left: 80.0 + (i % 3) * 40,
                      child: Icon(
                        Icons.water_drop,
                        size: 14,
                        color: AppColors.brandSky.withValues(alpha: 0.55),
                      )
                          .animate(onPlay: (c) => c.repeat())
                          .moveY(
                            begin: 0,
                            end: 40,
                            duration: (900 + i * 120).ms,
                          )
                          .fadeOut(),
                    );
                  }),
                  const Positioned(
                    bottom: 24,
                    child: Text('Мий губкою — води пальцем по персонажу'),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => setState(() => _inShower = !_inShower),
                  icon: const Icon(Icons.shower),
                  label: Text(_inShower ? 'У ванну' : 'У душ'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(characterProvider.notifier).brushTeeth();
                    setState(() => _moodText = 'Зубки чисті! 😁');
                  },
                  icon: const Icon(Icons.mood),
                  label: const Text('Чистити зуби'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(characterProvider.notifier).comb();
                    setState(() => _moodText = 'Зачіска готова ✨');
                  },
                  icon: const Icon(Icons.content_cut),
                  label: const Text('Розчесати'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(characterProvider.notifier).toilet();
                    setState(() => _moodText = 'Фух, легше!');
                  },
                  icon: const Icon(Icons.wc),
                  label: const Text('Туалет'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
