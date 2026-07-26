import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/hive_boxes.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/enums.dart';
import 'ai_model_service.dart';
import 'character_service.dart';

/// Local rule-based companion brain (placeholder for on-device LLM).
class ChatService {
  ChatService(this._character, this._models);

  final CharacterService _character;
  final AiModelService _models;
  final _uuid = const Uuid();
  final _rng = Random();

  List<ChatMessage> loadHistory() {
    final raw = HiveBoxes.chat.get('history');
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> _save(List<ChatMessage> msgs) async {
    // Keep last 200.
    final trimmed =
        msgs.length > 200 ? msgs.sublist(msgs.length - 200) : msgs;
    await HiveBoxes.chat.put('history', trimmed.map((e) => e.toJson()).toList());
  }

  Future<ChatMessage> sendUserText(String text, {bool voice = false}) async {
    final history = loadHistory();
    final userMsg = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.user,
      text: text.trim(),
      createdAt: DateTime.now(),
      isVoice: voice,
    );
    history.add(userMsg);

    final reply = await _generateReply(text);
    history.add(reply);
    await _save(history);
    await _character.socialize(4);
    return reply;
  }

  Future<ChatMessage> _generateReply(String input) async {
    final c = _character.load();
    final age = c?.age ?? 4;
    final name = c?.name ?? 'Мася';
    final mood = c?.mood ?? 70;
    final stage = c?.stage ?? AgeStage.child;
    final memory = _models.loadMemory();
    final lower = input.toLowerCase();

    String text;
    if (lower.contains('привіт') || lower.contains('hello') || lower.contains('вітаю')) {
      text = _greet(name, age, mood);
    } else if (lower.contains('їсти') || lower.contains('голод')) {
      text = mood < 40
          ? 'Я трохи засмучен${_ending(c)}... але їсти справді хочеться.'
          : 'Так! Ходімо на кухню, я зголоднів${_ending(c)}!';
    } else if (lower.contains('сон') || lower.contains('спати')) {
      text = age < 10
          ? 'Можна з нічником і колисковою? Мені так спокійніше.'
          : 'Добре, якщо вимкнеш світло — я ляжу.';
    } else if (lower.contains('гра')) {
      text = 'У ігровій кімнаті стільки всього! Обери гру — я з тобою.';
    } else if (c != null && c.needs.hunger < 25) {
      text = 'До речі... я дуже голодн${_ending(c)}. Може, погодуєш мене?';
    } else if (c != null && c.needs.energy < 25) {
      text = 'Оченята злипаються... Може, дрімочку?';
    } else {
      text = _ageAwareReply(stage, name, input, mood, memory);
    }

    return ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.character,
      text: text,
      createdAt: DateTime.now(),
    );
  }

  String _greet(String name, int age, double mood) {
    if (mood < 35) return 'Привіт... мені сьогодні трохи сумно.';
    if (age < 10) return 'Привітик! Я $name! Давай гратися?';
    if (age < 18) return 'Хей! Я $name. Що нового?';
    return 'Вітаю. Я $name — радий${_endingAge(age)} тебе бачити.';
  }

  String _ageAwareReply(
    AgeStage stage,
    String name,
    String input,
    double mood,
    dynamic memory,
  ) {
    final snippets = switch (stage) {
      AgeStage.child => [
          'Ого! Розкажи ще!',
          'А можна намалювати це уявою?',
          'Хе-хе, цікаво! А що далі?',
          'Я $name, і мені подобається говорити з тобою!',
        ],
      AgeStage.teen => [
          'Ну ок, звучить нормально. А детальніше?',
          'Я б теж так подумав. Що скажеш ще?',
          'Цікава тема. Хочеш розберемо разом?',
        ],
      AgeStage.youngAdult => [
          'Розумію. Давай глянемо на це практично.',
          'Можу допомогти структуровано. З чого почнемо?',
          'Дякую, що ділишся. Це важливо.',
        ],
      AgeStage.adult => [
          'Має сенс. Ось кілька варіантів, як підійти.',
          'Бачу контекст. Хочеш план на сьогодні?',
          'Слухаю уважно — продовжуй.',
        ],
      AgeStage.senior => [
          'З віком я навчився помічати головне. Розкажи ще.',
          'Мудре рішення іноді найпростіше. Що відчуваєш?',
          'Я поруч. Давай подумаємо спокійно.',
        ],
    };
    var base = snippets[_rng.nextInt(snippets.length)];
    if (mood > 80) base = '😊 $base';
    if (mood < 40) base = '…$base';
    return base;
  }

  String _ending(dynamic c) {
    if (c == null) return 'ий';
    return c.type == CharacterType.masya ? 'а' : 'ий';
  }

  String _endingAge(int age) => age >= 18 ? '' : 'ий';

  Future<ChatMessage> lifeTip({
    required int userAge,
    required String countryCode,
  }) async {
    final tips = _tips(userAge, countryCode);
    final tip = tips[_rng.nextInt(tips.length)];
    final msg = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.character,
      text: tip,
      createdAt: DateTime.now(),
      isLifeTip: true,
    );
    final history = loadHistory()..add(msg);
    await _save(history);
    return msg;
  }

  List<String> _tips(int userAge, String country) {
    final base = <String>[
      'Не забувай пити воду протягом дня.',
      'Короткі паузи кожні 50 хвилин роботи дуже допомагають.',
      'Вечірнє світло краще приглушити — так легше заснути.',
    ];
    if (userAge < 16) {
      base.addAll([
        'Після школи варто трохи порухатися — хоча б 15 хвилин.',
        'Якщо щось важко — спитай дорослого, якому довіряєш.',
      ]);
    } else if (userAge < 25) {
      base.addAll([
        'Сон 7–9 годин важливіший за ще одну годину скролу.',
        'Склади маленький список із 3 справ на день — і зробіть їх.',
      ]);
    } else {
      base.addAll([
        'Плануй відновлення так само серйозно, як роботу.',
        'Короткі прогулянки покращують ясність думок.',
      ]);
    }
    if (country.toUpperCase() == 'UA') {
      base.add('Перевір місцеві поради з безпеки та розкладу в твоєму регіоні.');
    }
    return base;
  }

  Future<void> clearHistory() async {
    await HiveBoxes.chat.delete('history');
  }
}

final chatServiceProvider = Provider<ChatService>(
  (ref) => ChatService(
    ref.watch(characterServiceProvider),
    ref.watch(aiModelServiceProvider),
  ),
);
