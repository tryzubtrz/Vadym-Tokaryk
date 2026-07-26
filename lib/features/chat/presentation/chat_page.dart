import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/chat_message.dart';
import '../../../domain/services/growth_service.dart';
import '../../../features/character/providers/character_animation_provider.dart';
import '../../../features/character/widgets/rive_character_view.dart';
import '../../../shared/providers/app_providers.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _voice = false;
  bool _cameraOn = false;
  DateTime? _sessionStart;

  @override
  void initState() {
    super.initState();
    _sessionStart = DateTime.now();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _flushChatXp() async {
    final start = _sessionStart;
    if (start == null) return;
    final minutes = DateTime.now().difference(start).inMinutes;
    if (minutes <= 0) return;
    await ref.read(growthServiceProvider).awardChatMinutes(minutes);
    await ref.read(characterProvider.notifier).refresh();
    _sessionStart = DateTime.now();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    ref.read(characterAnimationProvider.notifier).setTalking(true);
    await ref.read(chatHistoryProvider.notifier).send(text, voice: _voice);
    ref.read(characterAnimationProvider.notifier).setTalking(false);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final character = ref.watch(characterProvider);
    final history = ref.watch(chatHistoryProvider);
    if (character == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) await _flushChatXp();
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Спілкування'),
        actions: [
          IconButton(
            tooltip: 'Життєва підказка',
            onPressed: () => ref.read(chatHistoryProvider.notifier).tip(),
            icon: const Icon(Icons.lightbulb_outline),
          ),
          IconButton(
            tooltip: 'Камера',
            onPressed: () => setState(() => _cameraOn = !_cameraOn),
            icon: Icon(_cameraOn ? Icons.videocam : Icons.videocam_off),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.38,
            decoration: const BoxDecoration(gradient: AppColors.heroGradient),
            child: Stack(
              alignment: Alignment.center,
              children: [
                RiveCharacterView(
                  character: character,
                  size: 200,
                ),
                if (_cameraOn)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      width: 90,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(Icons.person, color: Colors.white54, size: 40),
                      ),
                    ),
                  ),
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Text(
                    'Настрій: ${character.mood.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: history.length,
              itemBuilder: (context, i) {
                final m = history[i];
                final mine = m.role == ChatRole.user;
                return Align(
                  alignment:
                      mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: mine
                          ? AppColors.brandCoral.withValues(alpha: 0.15)
                          : m.isLifeTip
                              ? AppColors.brandSun.withValues(alpha: 0.25)
                              : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${m.isVoice ? '🎤 ' : ''}${m.text}',
                    ),
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
                  IconButton(
                    onPressed: () => setState(() => _voice = !_voice),
                    icon: Icon(
                      _voice ? Icons.mic : Icons.mic_none,
                      color: _voice ? AppColors.brandCoral : null,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: InputDecoration(
                        hintText: _voice
                            ? 'Голосовий режим (текст як розпізнавання)'
                            : 'Напиши повідомлення…',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    onPressed: _send,
                    icon: const Icon(Icons.send_rounded, color: AppColors.brandCoral),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}
