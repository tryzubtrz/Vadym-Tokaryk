import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../character/domain/character_model.dart';
import '../../character/providers/app_providers.dart';
import '../../character/widgets/living_character.dart';
import '../../growth/presentation/growth_sheet.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  CharacterPose _pose = CharacterPose.idle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(characterProvider.notifier).tickNeeds();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(characterProvider);
    if (c == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final w = MediaQuery.sizeOf(context).width;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/rooms/bg_living_empty.png',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE8F6FF), Color(0xFFD4F0E8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.05),
            child: LivingCharacter(
              character: c,
              size: w * 0.68,
              pose: _pose,
              onTap: () async {
                setState(() => _pose = CharacterPose.react);
                await ref.read(characterProvider.notifier).tapReact();
              },
            ),
          ).animate().fadeIn(duration: 400.ms).scale(
                begin: const Offset(0.94, 0.94),
                curve: Curves.easeOutBack,
              ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => showGrowthSheet(context),
                        child: _AgeRing(
                          age: c.ageYears,
                          progress: c.yearProgress,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'MyMasyaAI',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              shadows: const [
                                Shadow(blurRadius: 8, color: Colors.black45),
                              ],
                            ),
                      ),
                      const Spacer(),
                      _roundIcon(Icons.campaign_rounded, () => context.push('/news')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/economy'),
                        child: _currencyChip(
                          AppColors.sun,
                          Icons.monetization_on_rounded,
                          c.regularCoins,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => context.push('/economy'),
                        child: _currencyChip(
                          AppColors.sky,
                          Icons.diamond_rounded,
                          c.donateCoins,
                        ),
                      ),
                      const Spacer(),
                      _roundIcon(
                        Icons.settings_rounded,
                        () => context.push('/settings'),
                      ),
                      const SizedBox(width: 6),
                      _roundIcon(
                        Icons.people_alt_rounded,
                        () => context.push('/friends'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 100,
            child: _NeedsRow(character: c),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _nav(Icons.restaurant_rounded, AppColors.hunger, 'Кухня',
                      () {
                    setState(() => _pose = CharacterPose.eat);
                    context.push('/kitchen');
                  }),
                  _nav(Icons.bathtub_rounded, AppColors.sky, 'Ванна',
                      () => context.push('/bathroom')),
                  _nav(Icons.chat_bubble_rounded, AppColors.mint, 'Чат', () {
                    setState(() => _pose = CharacterPose.happy);
                    context.push('/chat');
                  }, big: true),
                  _nav(Icons.bed_rounded, AppColors.violet, 'Сон', () {
                    setState(() => _pose = CharacterPose.sleep);
                    context.push('/bedroom');
                  }),
                  _nav(Icons.sports_esports_rounded, AppColors.sun, 'Ігри',
                      () => context.push('/games')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nav(
    IconData icon,
    Color color,
    String tip,
    VoidCallback onTap, {
    bool big = false,
  }) {
    final size = big ? 66.0 : 54.0;
    return Tooltip(
      message: tip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: big ? 30 : 24),
        ),
      ),
    );
  }

  Widget _roundIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _currencyChip(Color color, IconData icon, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgeRing extends StatelessWidget {
  const _AgeRing({required this.age, required this.progress});
  final int age;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      height: 62,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress.clamp(0.04, 1),
            strokeWidth: 4.5,
            backgroundColor: Colors.white24,
            color: const Color(0xFFE8B0FF),
          ),
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFFF8A65), AppColors.coral],
              ),
            ),
            child: Text(
              '$age',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NeedsRow extends StatelessWidget {
  const _NeedsRow({required this.character});
  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final items = <(String, double, Color, IconData)>[
      ('Голод', character.hunger, AppColors.hunger, Icons.restaurant),
      (
        'Чистота',
        character.cleanliness,
        AppColors.cleanliness,
        Icons.water_drop
      ),
      ('Енергія', character.energy, AppColors.energy, Icons.bolt),
      ('Гра', character.fun, AppColors.fun, Icons.sports_esports),
      ('Соціум', character.social, AppColors.social, Icons.favorite),
      ('Туалет', character.toilet, AppColors.toilet, Icons.wc),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (final i in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(i.$4, color: i.$3, size: 14),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 52,
                    child: Text(
                      i.$1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (i.$2 / 100).clamp(0, 1),
                        minHeight: 7,
                        backgroundColor: Colors.white24,
                        color: i.$3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
