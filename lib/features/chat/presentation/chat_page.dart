import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/hive_boxes.dart';
import '../../../core/theme/app_colors.dart';
import '../../character/domain/enums.dart';
import '../../character/providers/app_providers.dart';
import '../../character/widgets/living_character.dart';

class ChatMessage {
  ChatMessage({required this.text, required this.isUser, this.tip = false});
  final String text;
  final bool isUser;
  final bool tip;
}

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <ChatMessage>[];
  DateTime? _started;

  @override
  void initState() {
    super.initState();
    _started = DateTime.now();
    final raw = HiveBoxes.chatBox.get('history');
    if (raw is List) {
      for (final m in raw.whereType<Map>()) {
        _messages.add(
          ChatMessage(
            text: m['text'] as String? ?? '',
            isUser: m['user'] as bool? ?? false,
            tip: m['tip'] as bool? ?? false,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _flushXp();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _flushXp() async {
    final start = _started;
    if (start == null) return;
    final minutes = DateTime.now().difference(start).inMinutes;
    if (minutes >= 1) {
      await ref
          .read(characterProvider.notifier)
          .awardXp(minutes * 8, minutes);
      await ref.read(characterProvider.notifier).socialize(minutes * 2.0);
    }
    _started = DateTime.now();
  }

  Future<void> _persist() async {
    await HiveBoxes.chatBox.put(
      'history',
      _messages
          .map((m) => {'text': m.text, 'user': m.isUser, 'tip': m.tip})
          .toList(),
    );
  }

  String _reply(String text, CharacterType type, AgeStage stage) {
    final name = type.labelUk;
    if (text.toLowerCase().contains('привіт') ||
        text.toLowerCase().contains('hello')) {
      return 'Привіт! Я $name. Як твої справи?';
    }
    return switch (stage) {
      AgeStage.child => 'Хе-хе! Давай грати або їсти смачненьке!',
      AgeStage.teen => 'Ок, чую тебе. Може міні-гру або прогулянку?',
      AgeStage.youngAdult => 'Дякую, що ділишся. Я поруч і слухаю.',
      AgeStage.adult => 'Розумію. Хочеш пораду чи просто поговорити?',
      AgeStage.senior => 'З роками я навчився цінувати такі розмови.',
    };
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    final c = ref.read(characterProvider);
    if (c == null) return;
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _messages.add(
        ChatMessage(
          text: _reply(text, c.type, c.ageStage),
          isUser: false,
        ),
      );
    });
    await _persist();
    await ref.read(characterProvider.notifier).socialize(4);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _tip() async {
    final tips = [
      'Пий воду протягом дня — це заряд для тіла і настрою.',
      'Короткий відпочинок кращий за вигорання.',
      'Подзвони другу — соціальний контакт лікує.',
    ];
    setState(() {
      _messages.add(
        ChatMessage(
          text: tips[DateTime.now().second % tips.length],
          isUser: false,
          tip: true,
        ),
      );
    });
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(characterProvider);
    if (c == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Спілкування'),
        actions: [
          IconButton(onPressed: _tip, icon: const Icon(Icons.lightbulb_outline)),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: MediaQuery.sizeOf(context).height * 0.28,
            decoration: const BoxDecoration(gradient: AppColors.splash),
            child: Center(
              child: LivingCharacter(character: c, size: 160),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                return Align(
                  alignment:
                      m.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: m.isUser
                          ? AppColors.coral.withValues(alpha: 0.15)
                          : m.tip
                              ? AppColors.sun.withValues(alpha: 0.25)
                              : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(m.text),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: const InputDecoration(
                        hintText: 'Напиши повідомлення…',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    onPressed: _send,
                    icon: const Icon(Icons.send_rounded, color: AppColors.coral),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
