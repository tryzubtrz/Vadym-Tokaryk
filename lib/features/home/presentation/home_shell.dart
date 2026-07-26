import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/enums.dart';
import '../../../features/character/animation/character_animator.dart';
import '../../../shared/providers/app_providers.dart';
import '../widgets/tom_style_ui.dart';

/// Main play screen — Talking Tom layout:
/// full-bleed room · big character · level badge · currencies · circular actions.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _action = 1; // smile / main
  CharacterPose _pose = CharacterPose.idle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(characterProvider.notifier).refresh();
      await ref.read(growthDayProvider.notifier).ensureQuestion();
    });
  }

  void _setAction(int i, {CharacterPose pose = CharacterPose.idle}) {
    setState(() {
      _action = i;
      _pose = pose;
    });
  }

  @override
  Widget build(BuildContext context) {
    final character = ref.watch(characterProvider);
    final growth = ref.watch(growthDayProvider);
    final downloadLabel = ref.watch(downloadLabelProvider);
    final downloadProgress = ref.watch(downloadProgressProvider);

    if (character == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed room
          const RoomSceneBackground(kind: RoomSceneKind.living),
          const FloatingDecor(),

          // Top HUD
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LevelBadge(
                        level: character.age,
                        progress: character.yearProgress,
                      ),
                      const SizedBox(width: 8),
                      // Plane / news + friends shortcuts
                      _roundIcon(
                        Icons.campaign_rounded,
                        () => context.push('/news'),
                        alert: true,
                      ),
                      const Spacer(),
                      TomCurrencyBar(
                        coins: character.coins,
                        gems: character.donateCoins,
                      ),
                      const SizedBox(width: 6),
                      _roundIcon(
                        Icons.settings_rounded,
                        () => context.push('/settings'),
                      ),
                    ],
                  ),
                  if (downloadLabel != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            downloadLabel,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          LinearProgressIndicator(value: downloadProgress),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Character center
          Align(
            alignment: const Alignment(0, 0.15),
            child: CharacterAnimator(
              character: character,
              size: MediaQuery.of(context).size.width * 0.78,
              pose: character.isSleeping ? CharacterPose.sleep : _pose,
              talking: ref.watch(characterTalkingProvider),
              reaction: ref.read(characterProvider.notifier).lastGesture,
              onTap: () {
                _setAction(1, pose: CharacterPose.happy);
                ref
                    .read(characterProvider.notifier)
                    .interact(InteractionGesture.tap);
              },
              onStroke: () {
                _setAction(1, pose: CharacterPose.happy);
                ref
                    .read(characterProvider.notifier)
                    .interact(InteractionGesture.stroke);
              },
              onPoke: () => ref
                  .read(characterProvider.notifier)
                  .interact(InteractionGesture.pokeForehead),
              onShake: () => ref
                  .read(characterProvider.notifier)
                  .interact(InteractionGesture.shake),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: 0, end: -6, duration: 2200.ms),
          ),

          // Name chip
          Positioned(
            left: 0,
            right: 0,
            bottom: 110,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${character.name} · IQ ${character.iq}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),

          // Daily question floating
          if (growth.dailyQuestionAsked &&
              !growth.dailyQuestionAnswered &&
              growth.dailyQuestionText != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 170,
              child: _DailyBubble(
                question: growth.dailyQuestionText!,
                onAnswer: (a) async {
                  final msg = await ref
                      .read(growthDayProvider.notifier)
                      .answerQuestion(a);
                  if (context.mounted && msg != null) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(msg)));
                  }
                },
              ),
            ),

          // Circular bottom actions (Talking Tom style)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.25),
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TomActionButton(
                      icon: Icons.shopping_cart_rounded,
                      color: const Color(0xFF5A5A5A),
                      selected: _action == 0,
                      badge: '1',
                      onTap: () {
                        _setAction(0);
                        context.push('/economy');
                      },
                    ),
                    TomActionButton(
                      icon: Icons.emoji_emotions_rounded,
                      color: const Color(0xFF3DDC84),
                      selected: _action == 1,
                      onTap: () {
                        _setAction(1, pose: CharacterPose.happy);
                        context.push('/chat');
                      },
                    ),
                    TomActionButton(
                      icon: Icons.restaurant_rounded,
                      color: const Color(0xFFE53935),
                      selected: _action == 2,
                      onTap: () {
                        _setAction(2, pose: CharacterPose.eat);
                        context.push('/kitchen');
                      },
                    ),
                    TomActionButton(
                      icon: Icons.wc_rounded,
                      color: const Color(0xFF29B6F6),
                      selected: _action == 3,
                      onTap: () {
                        _setAction(3);
                        context.push('/bathroom');
                      },
                    ),
                    TomActionButton(
                      icon: Icons.bedtime_rounded,
                      color: const Color(0xFFAB47BC),
                      selected: _action == 4,
                      onTap: () {
                        _setAction(4, pose: CharacterPose.sleep);
                        context.push('/bedroom');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Side shortcuts like Tom (games / friends / outfits)
          Positioned(
            right: 10,
            top: MediaQuery.of(context).size.height * 0.28,
            child: Column(
              children: [
                _sideFab(Icons.sports_esports, () => context.push('/games')),
                const SizedBox(height: 10),
                _sideFab(Icons.people_alt, () => context.push('/friends')),
                const SizedBox(height: 10),
                _sideFab(Icons.checkroom, () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Гардероб / скіни — скоро'),
                    ),
                  );
                }),
                if (character.photoRoomUnlocked) ...[
                  const SizedBox(height: 10),
                  _sideFab(Icons.photo_camera, () => context.push('/photo')),
                ],
                if (character.codeRoomUnlocked) ...[
                  const SizedBox(height: 10),
                  _sideFab(Icons.code, () => context.push('/code')),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundIcon(IconData icon, VoidCallback onTap, {bool alert = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          if (alert)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sideFab(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Icon(icon, color: AppColors.brandInk),
      ),
    );
  }
}

class _DailyBubble extends StatefulWidget {
  const _DailyBubble({required this.question, required this.onAnswer});
  final String question;
  final ValueChanged<String> onAnswer;

  @override
  State<_DailyBubble> createState() => _DailyBubbleState();
}

class _DailyBubbleState extends State<_DailyBubble> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(18),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '❓ ${widget.question}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration(
                      hintText: 'Відповідь…',
                      isDense: true,
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    if (_ctrl.text.trim().isEmpty) return;
                    widget.onAnswer(_ctrl.text.trim());
                  },
                  icon: const Icon(Icons.send, color: AppColors.brandCoral),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
