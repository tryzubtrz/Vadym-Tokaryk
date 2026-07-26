import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../features/character/animation/character_animator.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

class BedroomPage extends ConsumerStatefulWidget {
  const BedroomPage({super.key});

  @override
  ConsumerState<BedroomPage> createState() => _BedroomPageState();
}

class _BedroomPageState extends ConsumerState<BedroomPage> {
  bool _lightsOff = false;
  bool _nightLight = false;
  bool _lullaby = false;
  String? _dream;

  @override
  Widget build(BuildContext context) {
    final character = ref.watch(characterProvider);
    if (character == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bg = _lightsOff
        ? AppColors.bedroomGradient
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF0E0), Color(0xFFE8D4FF)],
          );

    return GradientScaffold(
      gradient: bg,
      appBar: AppBar(
        title: const Text('Спальня'),
        foregroundColor: _lightsOff ? Colors.white : null,
      ),
      child: Column(
        children: [
          Text(
            'Енергія: ${character.needs.energy.toStringAsFixed(0)}%',
            style: TextStyle(
              color: _lightsOff ? Colors.white70 : AppColors.brandInk,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_dream != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _dream!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _lightsOff ? Colors.white : AppColors.brandInk,
                  fontWeight: FontWeight.w700,
                ),
              ).animate().fadeIn(),
            ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Bed
                Positioned(
                  bottom: 40,
                  child: Container(
                    width: 280,
                    height: 90,
                    decoration: BoxDecoration(
                      color: _lightsOff
                          ? const Color(0xFF3A4068)
                          : const Color(0xFFFFD6E0),
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                ),
                CharacterAnimator(
                  character: character.copyWith(isSleeping: character.isSleeping),
                  size: 220,
                ),
                if (_nightLight)
                  Positioned(
                    right: 36,
                    bottom: 120,
                    child: Icon(
                      Icons.nightlight_round,
                      size: 36,
                      color: AppColors.brandSun.withValues(alpha: 0.85),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1)),
                  ),
                if (_lullaby)
                  Positioned(
                    left: 24,
                    top: 40,
                    child: const Text('🎵 ♪ ♫')
                        .animate(onPlay: (c) => c.repeat())
                        .moveX(begin: 0, end: 20, duration: 1600.ms),
                  ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => setState(() => _lightsOff = !_lightsOff),
                icon: Icon(_lightsOff ? Icons.lightbulb : Icons.lightbulb_outline),
                label: Text(_lightsOff ? 'Увімкнути світло' : 'Вимкнути світло'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _lightsOff ? Colors.white : null,
                  side: BorderSide(
                    color: _lightsOff ? Colors.white54 : AppColors.brandCoral,
                  ),
                ),
                onPressed: () => setState(() => _nightLight = !_nightLight),
                icon: const Icon(Icons.nightlight),
                label: Text(_nightLight ? 'Нічник вимк' : 'Нічник'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _lightsOff ? Colors.white : null,
                  side: BorderSide(
                    color: _lightsOff ? Colors.white54 : AppColors.brandCoral,
                  ),
                ),
                onPressed: () => setState(() => _lullaby = !_lullaby),
                icon: const Icon(Icons.music_note),
                label: Text(_lullaby ? 'Стоп колискова' : 'Колискова'),
              ),
              if (!character.isSleeping)
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await ref
                          .read(characterProvider.notifier)
                          .sleep(_lightsOff);
                      setState(() => _dream = null);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$e')),
                      );
                    }
                  },
                  child: const Text('Лягти спати'),
                )
              else
                ElevatedButton(
                  onPressed: () async {
                    await ref.read(characterProvider.notifier).wake();
                    final tell = Random().nextBool();
                    setState(() {
                      _dream = tell
                          ? '😴 Мені снилось, що ми літали на хмарах і їли тістечка!'
                          : 'Доброго ранку! Добре виспався.';
                      _lightsOff = false;
                    });
                  },
                  child: const Text('Прокинутись'),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
