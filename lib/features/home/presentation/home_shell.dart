import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/enums.dart';
import '../../../shared/providers/app_providers.dart';
import '../widgets/tom_style_ui.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _action = 1;
  CharacterPose _pose = CharacterPose.idle;

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
    final growth = ref.watch(growthDayProvider);
    final downloadLabel = ref.watch(downloadLabelProvider);
    final downloadProgress = ref.watch(downloadProgressProvider);

    if (character == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return TomRoomStage(
      kind: RoomSceneKind.living,
      character: character,
      pose: _pose,
      onCharacterTap: () {
        setState(() => _pose = CharacterPose.react);
        ref.read(characterProvider.notifier).interact(InteractionGesture.tap);
      },
      onStroke: () {
        setState(() => _pose = CharacterPose.happy);
        ref.read(characterProvider.notifier).interact(InteractionGesture.stroke);
      },
      onPoke: () =>
          ref.read(characterProvider.notifier).interact(InteractionGesture.pokeForehead),
      onShake: () =>
          ref.read(characterProvider.notifier).interact(InteractionGesture.shake),
      topBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Column(
          children: [
            Row(
              children: [
                LevelBadge(
                  level: character.age,
                  progress: character.yearProgress,
                ),
                const SizedBox(width: 8),
                _hudIcon(Icons.campaign_rounded, () => context.push('/news'),
                    alert: true),
                const Spacer(),
                TomCurrencyBar(
                  coins: character.coins,
                  gems: character.donateCoins,
                ),
                const SizedBox(width: 6),
                _hudIcon(
                  Icons.settings_rounded,
                  () => context.push('/settings'),
                ),
              ],
            ),
            if (downloadLabel != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
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
      sideBar: Column(
        children: [
          TomSideFab(
            icon: Icons.sports_esports,
            onTap: () => context.push('/games'),
          ),
          TomSideFab(
            icon: Icons.people_alt,
            onTap: () => context.push('/friends'),
          ),
          TomSideFab(
            icon: Icons.checkroom,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Гардероб — скоро')),
              );
            },
          ),
        ],
      ),
      overlay: growth.dailyQuestionAsked &&
              !growth.dailyQuestionAnswered &&
              growth.dailyQuestionText != null
          ? Positioned(
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
            )
          : null,
      bottomBar: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TomActionButton(
              icon: Icons.shopping_cart_rounded,
              color: const Color(0xFF5A5A5A),
              selected: _action == 0,
              badge: '1',
              onTap: () {
                setState(() => _action = 0);
                context.push('/economy');
              },
            ),
            TomActionButton(
              icon: Icons.emoji_emotions_rounded,
              color: const Color(0xFF3DDC84),
              selected: _action == 1,
              onTap: () {
                setState(() {
                  _action = 1;
                  _pose = CharacterPose.happy;
                });
                context.push('/chat');
              },
            ),
            TomActionButton(
              icon: Icons.restaurant_rounded,
              color: const Color(0xFFE53935),
              selected: _action == 2,
              onTap: () {
                setState(() {
                  _action = 2;
                  _pose = CharacterPose.eat;
                });
                context.push('/kitchen');
              },
            ),
            TomActionButton(
              icon: Icons.wc_rounded,
              color: const Color(0xFF29B6F6),
              selected: _action == 3,
              onTap: () {
                setState(() => _action = 3);
                context.push('/bathroom');
              },
            ),
            TomActionButton(
              icon: Icons.bedtime_rounded,
              color: const Color(0xFFAB47BC),
              selected: _action == 4,
              onTap: () {
                setState(() {
                  _action = 4;
                  _pose = CharacterPose.sleep;
                });
                context.push('/bedroom');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _hudIcon(IconData icon, VoidCallback onTap, {bool alert = false}) {
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
              color: Colors.black.withValues(alpha: 0.35),
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
      elevation: 6,
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
                  icon: const Icon(Icons.send, color: Color(0xFFE85D4C)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
