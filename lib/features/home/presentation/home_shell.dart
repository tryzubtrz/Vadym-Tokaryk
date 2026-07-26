import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/enums.dart';
import '../../../features/character/animation/character_animator.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/currency_badge.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/need_bar.dart';
import '../../../shared/widgets/progress_year_bar.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(characterProvider.notifier).refresh();
      await ref.read(growthDayProvider.notifier).ensureQuestion();
    });
  }

  @override
  Widget build(BuildContext context) {
    final character = ref.watch(characterProvider);
    final user = ref.watch(userProvider);
    final growth = ref.watch(growthDayProvider);
    final downloadLabel = ref.watch(downloadLabelProvider);
    final downloadProgress = ref.watch(downloadProgressProvider);
    final tab = ref.watch(mainTabProvider);

    if (character == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final rooms = [
      ('/kitchen', 'Кухня', Icons.kitchen_rounded),
      ('/bathroom', 'Ванна', Icons.bathtub_rounded),
      ('/bedroom', 'Спальня', Icons.bed_rounded),
      ('/games', 'Ігри', Icons.sports_esports_rounded),
      ('/chat', 'Чат', Icons.chat_rounded),
    ];

    return GradientScaffold(
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tab.clamp(0, 4),
        onTap: (i) {
          ref.read(mainTabProvider.notifier).state = i;
          context.push(rooms[i].$1);
        },
        items: [
          for (final r in rooms)
            BottomNavigationBarItem(icon: Icon(r.$3), label: r.$2),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.push('/settings'),
                  icon: const Icon(Icons.settings_rounded),
                  tooltip: 'Налаштування',
                ),
                IconButton(
                  onPressed: () => context.push('/friends'),
                  icon: const Icon(Icons.people_alt_rounded),
                  tooltip: 'Друзі',
                ),
                IconButton(
                  onPressed: () => context.push('/news'),
                  icon: const Icon(Icons.campaign_rounded),
                  tooltip: 'Новини',
                ),
                const Spacer(),
                CurrencyBadge(
                  coins: character.coins,
                  donateCoins: character.donateCoins,
                ),
              ],
            ),
          ),
          if (downloadLabel != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  Text(downloadLabel, style: const TextStyle(fontSize: 12)),
                  LinearProgressIndicator(value: downloadProgress),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: ProgressYearBar(
              progress: character.yearProgress,
              age: character.age,
              iq: character.iq,
            ),
          ),
          Text(
            'Привіт, ${user?.displayName ?? 'друже'}! Я ${character.name}',
            style: Theme.of(context).textTheme.titleMedium,
          ).animate().fadeIn().slideY(begin: 0.2, end: 0),
          Text(
            '#${character.sequentialId} · ${character.stage.labelUk}'
            '${character.hasBeard ? ' · борідка' : ''}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Expanded(
            child: Center(
              child: CharacterAnimator(
                character: character,
                size: MediaQuery.of(context).size.width * 0.72,
                talking: ref.watch(characterTalkingProvider),
                reaction: ref.read(characterProvider.notifier).lastGesture,
                onTap: () => ref
                    .read(characterProvider.notifier)
                    .interact(InteractionGesture.tap),
                onStroke: () => ref
                    .read(characterProvider.notifier)
                    .interact(InteractionGesture.stroke),
                onPoke: () => ref
                    .read(characterProvider.notifier)
                    .interact(InteractionGesture.pokeForehead),
                onShake: () => ref
                    .read(characterProvider.notifier)
                    .interact(InteractionGesture.shake),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(begin: 0, end: -4, duration: 2400.ms),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: NeedsRow(
              needs: {
                for (final t in NeedType.values) t: character.needs.of(t),
              },
            ),
          ),
          const SizedBox(height: 8),
          if (growth.dailyQuestionAsked &&
              !growth.dailyQuestionAnswered &&
              growth.dailyQuestionText != null)
            _DailyQuestionBanner(
              question: growth.dailyQuestionText!,
              onAnswer: (a) async {
                final msg =
                    await ref.read(growthDayProvider.notifier).answerQuestion(a);
                if (context.mounted && msg != null) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(msg)));
                }
              },
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              children: [
                _QuickChip(
                  label: 'Фото',
                  locked: !character.photoRoomUnlocked,
                  onTap: () => context.push('/photo'),
                ),
                _QuickChip(
                  label: 'Код',
                  locked: !character.codeRoomUnlocked,
                  onTap: () => context.push('/code'),
                ),
                _QuickChip(
                  label: 'Пітомець',
                  locked: !character.petUnlocked,
                  onTap: () => context.push('/pet'),
                ),
                _QuickChip(
                  label: 'Догляд',
                  onTap: () => _showCareSheet(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCareSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final day = ref.watch(growthDayProvider);
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Щоденний догляд',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  for (final slot in CareSlot.values)
                    ListTile(
                      leading: Icon(
                        day.careDone(slot)
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        color: AppColors.brandCoral,
                      ),
                      title: Text(switch (slot) {
                        CareSlot.morning => 'Ранковий догляд',
                        CareSlot.day => 'Денний догляд',
                        CareSlot.evening => 'Вечірній догляд',
                      }),
                      trailing: day.careDone(slot)
                          ? const Text('Готово')
                          : TextButton(
                              onPressed: () async {
                                // Mark care after visiting rooms conceptually.
                                final msg = await ref
                                    .read(growthDayProvider.notifier)
                                    .completeCare(slot);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  if (msg != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(msg)),
                                    );
                                  }
                                }
                              },
                              child: const Text('Зарахувати'),
                            ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.onTap,
    this.locked = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: OutlinedButton(
          onPressed: locked
              ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$label ще зачинено')),
                  );
                }
              : onTap,
          child: Text(
            locked ? '🔒 $label' : label,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ),
    );
  }
}

class _DailyQuestionBanner extends StatefulWidget {
  const _DailyQuestionBanner({
    required this.question,
    required this.onAnswer,
  });

  final String question;
  final ValueChanged<String> onAnswer;

  @override
  State<_DailyQuestionBanner> createState() => _DailyQuestionBannerState();
}

class _DailyQuestionBannerState extends State<_DailyQuestionBanner> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandSun.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '❓ Питання дня (1 година)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(widget.question),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  decoration: const InputDecoration(
                    hintText: 'Твоя відповідь…',
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  if (_ctrl.text.trim().isEmpty) return;
                  widget.onAnswer(_ctrl.text.trim());
                },
                icon: const Icon(Icons.send_rounded, color: AppColors.brandCoral),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
