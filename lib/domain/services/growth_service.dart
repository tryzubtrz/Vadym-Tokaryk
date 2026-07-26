import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/growth_balance.dart';
import '../../data/local/hive_boxes.dart';
import '../../data/models/character_model.dart';
import '../../data/models/enums.dart';
import '../../data/models/growth_state.dart';
import '../../data/models/memory_packet.dart';
import 'ai_model_service.dart';
import 'character_service.dart';
import 'time_guard_service.dart';

class GrowthEvent {
  const GrowthEvent({
    required this.xpGained,
    required this.coinsGained,
    this.leveledUp = false,
    this.newAge,
    this.stageChanged = false,
    this.message,
  });

  final int xpGained;
  final int coinsGained;
  final bool leveledUp;
  final int? newAge;
  final bool stageChanged;
  final String? message;
}

class GrowthService {
  GrowthService(this._character, this._models, this._time);

  final CharacterService _character;
  final AiModelService _models;
  final TimeGuardService _time;
  final _rng = Random();

  GrowthState loadDay() {
    final today = GrowthState.today();
    final raw = HiveBoxes.growth.get('day');
    if (raw is Map) {
      final state = GrowthState.fromJson(Map<String, dynamic>.from(raw));
      if (state.dateKey == today.dateKey) return state;
    }
    final fresh = today;
    HiveBoxes.growth.put('day', fresh.toJson());
    return fresh;
  }

  Future<void> _saveDay(GrowthState s) async {
    await HiveBoxes.growth.put('day', s.toJson());
  }

  Future<GrowthEvent> completeCare(CareSlot slot) async {
    var day = loadDay();
    if (day.careDone(slot)) {
      return const GrowthEvent(
        xpGained: 0,
        coinsGained: 0,
        message: 'Цей догляд уже виконано сьогодні',
      );
    }
    final xp = switch (slot) {
      CareSlot.morning => GrowthBalance.morningCareXp,
      CareSlot.day => GrowthBalance.dayCareXp,
      CareSlot.evening => GrowthBalance.eveningCareXp,
    };
    day = switch (slot) {
      CareSlot.morning => day.copyWith(morningDone: true),
      CareSlot.day => day.copyWith(dayDone: true),
      CareSlot.evening => day.copyWith(eveningDone: true),
    };
    await _saveDay(day);
    return _applyXp(xp, GrowthBalance.careRoutineCoins);
  }

  Future<GrowthEvent> awardMiniGame({required bool won}) async {
    var day = loadDay();
    day = day.copyWith(gamesPlayedToday: day.gamesPlayedToday + 1);
    await _saveDay(day);
    final xp =
        won ? GrowthBalance.miniGameWinXp : GrowthBalance.miniGamePlayXp;
    final coins = won ? GrowthBalance.miniGameWinCoins : 3;
    await _character.playFun(won ? 18 : 8);
    return _applyXp(xp, coins);
  }

  Future<GrowthEvent> awardChatMinutes(int minutes) async {
    var day = loadDay();
    final prev = day.chatMinutesToday;
    day = day.copyWith(chatMinutesToday: prev + minutes);
    await _saveDay(day);
    await _character.socialize(minutes * 2.0);
    if (day.chatMinutesToday < GrowthBalance.chatMinMinutesForXp) {
      return const GrowthEvent(xpGained: 0, coinsGained: 0);
    }
    final grantable = minutes.clamp(0, 30);
    return _applyXp(grantable * GrowthBalance.chatMinuteXp, grantable);
  }

  Future<GrowthEvent> awardVideo() async {
    return _applyXp(
      GrowthBalance.videoRewardXp,
      GrowthBalance.videoRewardCoins,
    );
  }

  Future<GrowthState> ensureDailyQuestion() async {
    var day = loadDay();
    if (day.dailyQuestionAsked) return day;
    final now = await _time.now();
    final questions = _questionsForAge(_character.load()?.age ?? 4);
    final q = questions[_rng.nextInt(questions.length)];
    day = day.copyWith(
      dailyQuestionAsked: true,
      dailyQuestionText: q,
      dailyQuestionDeadline: now.add(AppConstants.dailyQuestionWindow),
    );
    await _saveDay(day);
    return day;
  }

  Future<GrowthEvent> answerDailyQuestion(String answer) async {
    var day = loadDay();
    if (!day.dailyQuestionAsked || day.dailyQuestionAnswered) {
      return const GrowthEvent(xpGained: 0, coinsGained: 0);
    }
    final now = await _time.now();
    if (day.dailyQuestionDeadline != null &&
        now.isAfter(day.dailyQuestionDeadline!)) {
      return const GrowthEvent(
        xpGained: 0,
        coinsGained: 0,
        message: 'Час на відповідь вичерпано (1 година)',
      );
    }
    day = day.copyWith(dailyQuestionAnswered: true);
    await _saveDay(day);
    // Store fact in memory.
    final facts = List<String>.from(
      HiveBoxes.chat.get('key_facts', defaultValue: <String>[]) as List,
    );
    facts.add(answer.trim());
    if (facts.length > 50) facts.removeRange(0, facts.length - 50);
    await HiveBoxes.chat.put('key_facts', facts);

    return _applyXp(
      GrowthBalance.dailyQuestionXp,
      GrowthBalance.dailyQuestionCoins,
    );
  }

  Future<GrowthEvent> _applyXp(int xp, int coins) async {
    var c = await _character.tick();
    final oldStage = c.stage;
    var growthXp = c.growthXp + xp;
    var age = c.age;
    var needed = c.growthXpNeeded;
    var iq = c.iq;
    var leveled = false;
    var stageChanged = false;

    while (growthXp >= needed) {
      growthXp -= needed;
      age += 1;
      leveled = true;
      needed = GrowthBalance.xpForAge(age);
      iq = (iq + 1 + _rng.nextInt(2)).clamp(80, 200);
      final newStage = AgeStageX.fromAge(age);
      if (newStage != oldStage) {
        stageChanged = true;
      }
    }

    c = c.copyWith(
      growthXp: growthXp,
      growthXpNeeded: needed,
      age: age,
      iq: iq,
      coins: c.coins + coins,
    );
    await _character.save(c);

    if (stageChanged) {
      await _onStageChange(c, oldStage, c.stage);
    }

    return GrowthEvent(
      xpGained: xp,
      coinsGained: coins,
      leveledUp: leveled,
      newAge: leveled ? age : null,
      stageChanged: stageChanged,
      message: leveled ? '${c.name} тепер має $age років!' : null,
    );
  }

  Future<void> _onStageChange(
    CharacterModel c,
    AgeStage from,
    AgeStage to,
  ) async {
    final userRaw = HiveBoxes.user.get('profile');
    final userName = userRaw is Map ? (userRaw['displayName'] as String?) : null;
    final userAge = userRaw is Map ? (userRaw['realAge'] as int?) : null;
    final prefs = List<String>.from(
      HiveBoxes.chat.get('preferences', defaultValue: <String>[]) as List,
    );
    final facts = List<String>.from(
      HiveBoxes.chat.get('key_facts', defaultValue: <String>[]) as List,
    );
    final packet = MemoryPacket(
      userName: userName ?? 'Друг',
      userAge: userAge ?? 12,
      characterName: c.name,
      preferences: prefs,
      keyFacts: facts,
      relationshipTone: 'warm',
      voiceSamplePath: c.voiceSamplePath,
    );
    await _models.transitionToStage(
      stage: to,
      memory: packet,
      voicePath: c.voiceSamplePath,
    );
    final modelId = '${to.name}_base_v1';
    await _character.save(c.copyWith(currentModelId: modelId));
  }

  List<String> _questionsForAge(int age) {
    if (age < 10) {
      return [
        'Який твій улюблений колір?',
        'Що ти любиш їсти на сніданок?',
        'Хочеш почути казку чи пограти?',
        'Як звати твого найкращого друга?',
      ];
    }
    if (age < 18) {
      return [
        'Який предмет у школі тобі найцікавіший?',
        'Про що ти мрієш останнім часом?',
        'Яку музику ти любиш?',
        'Хто надихає тебе найбільше?',
      ];
    }
    return [
      'Яка твоя головна ціль цього місяця?',
      'Що допомагає тобі відновлювати сили?',
      'Яка навичка тобі найбільше знадобиться?',
      'Що ти цінуєш у дружбі?',
    ];
  }
}

final growthServiceProvider = Provider<GrowthService>(
  (ref) => GrowthService(
    ref.watch(characterServiceProvider),
    ref.watch(aiModelServiceProvider),
    ref.watch(timeGuardProvider),
  ),
);
