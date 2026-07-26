import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/growth_balance.dart';
import '../../data/local/hive_boxes.dart';
import '../../data/models/character_model.dart';
import '../../data/models/enums.dart';
import '../../data/models/food_item.dart';
import 'time_guard_service.dart';

class CharacterService {
  CharacterService(this._time);

  final TimeGuardService _time;

  CharacterModel? load() {
    final raw = HiveBoxes.character.get('main');
    if (raw is Map) {
      return CharacterModel.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  Future<void> save(CharacterModel c) async {
    await HiveBoxes.character.put('main', c.toJson());
  }

  Future<int> nextSequentialId() async {
    final last = HiveBoxes.settings.get('last_sequential_id', defaultValue: 0)
        as int;
    final next = last + 1;
    await HiveBoxes.settings.put('last_sequential_id', next);
    return next;
  }

  Future<CharacterModel> create({
    required String name,
    required CharacterType type,
  }) async {
    final id = await nextSequentialId();
    final c = CharacterModel.create(
      sequentialId: id,
      name: name.trim(),
      type: type,
      growthXpNeeded: GrowthBalance.xpForAge(AppConstants.startAge),
    );
    await save(c);
    // Seed fridge with starter porridge x2 (free welcome).
    await _seedStarterFood();
    return c;
  }

  Future<void> _seedStarterFood() async {
    final list = <Map<String, dynamic>>[
      FoodCatalog.shop
          .firstWhere((f) => f.id == 'porridge')
          .copyWith(
            quantity: 2,
            expiresAt: DateTime.now().add(const Duration(days: 3)),
          )
          .toJson(),
      FoodCatalog.shop
          .firstWhere((f) => f.id == 'apple')
          .copyWith(
            quantity: 3,
            expiresAt: DateTime.now().add(const Duration(days: 5)),
          )
          .toJson(),
    ];
    await HiveBoxes.inventory.put('fridge', list);
  }

  List<FoodItem> loadFridge() {
    final raw = HiveBoxes.inventory.get('fridge');
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => FoodItem.fromJson(Map<String, dynamic>.from(e)))
        .where((f) => f.quantity > 0 && !f.isExpired)
        .toList();
  }

  Future<void> saveFridge(List<FoodItem> items) async {
    await HiveBoxes.inventory
        .put('fridge', items.map((e) => e.toJson()).toList());
  }

  /// Apply offline/online decay since last care.
  Future<CharacterModel> tick() async {
    var c = load();
    if (c == null) {
      throw StateError('Character not created');
    }
    final now = await _time.now();
    final hours =
        now.difference(c.lastCaredAt).inMinutes / 60.0;
    if (hours > 0.05) {
      var needs = c.needs.decay(hours);
      var dirt = c.dirtLevel + hours * 1.5;
      // Starvation tracking
      var daysWithout = c.daysWithoutFood;
      final daysSinceFed = now.difference(c.lastFedAt).inDays;
      if (daysSinceFed > daysWithout) {
        daysWithout = daysSinceFed;
      }
      var body = c.bodyShape;
      if (daysWithout >= AppConstants.starvationDaysForThin) {
        body = BodyShape.thin;
      }
      c = c.copyWith(
        needs: needs,
        dirtLevel: dirt.clamp(0, 100),
        daysWithoutFood: daysWithout,
        bodyShape: body,
        lastCaredAt: now,
        mood: (c.mood - hours * 0.8).clamp(0, 100),
      );
      await save(c);
    }
    return c;
  }

  Future<CharacterModel> feed(FoodItem food) async {
    var c = await tick();
    final fridge = loadFridge();
    final idx = fridge.indexWhere((f) => f.id == food.id);
    if (idx < 0) throw StateError('Їжі немає в холодильнику');
    final item = fridge[idx];
    if (item.quantity <= 1) {
      fridge.removeAt(idx);
    } else {
      fridge[idx] = item.copyWith(quantity: item.quantity - 1);
    }
    await saveFridge(fridge);

    final now = await _time.now();
    final newHunger = c.needs.hunger + food.hungerRestore;
    var overfeed = c.overfeedStreak;
    var body = c.bodyShape;
    if (newHunger > 100) {
      overfeed += 1;
      if (overfeed >= 3) body = BodyShape.plump;
    } else {
      overfeed = 0;
      if (body == BodyShape.thin && newHunger > 50) body = BodyShape.normal;
    }

    // Toilet fills a bit after eating.
    c = c.copyWith(
      needs: c.needs.copyWith(
        hunger: newHunger.clamp(0, 100),
        toilet: c.needs.toilet - 8,
        fun: c.needs.fun + 3,
      ),
      lastFedAt: now,
      daysWithoutFood: 0,
      overfeedStreak: overfeed,
      bodyShape: body,
      mood: (c.mood + 5).clamp(0, 100),
    );
    await save(c);
    return c;
  }

  Future<CharacterModel> buyFoodPack(FoodItem catalogItem, int packSize) async {
    var c = await tick();
    final price = FoodCatalog.packPrice(catalogItem, packSize);
    if (c.coins < price) throw StateError('Недостатньо коїнів');
    c = c.copyWith(coins: c.coins - price);
    final fridge = loadFridge();
    final existing = fridge.indexWhere((f) => f.id == catalogItem.id);
    final expires = DateTime.now().add(const Duration(days: 7));
    if (existing >= 0) {
      fridge[existing] = fridge[existing].copyWith(
        quantity: fridge[existing].quantity + packSize,
        expiresAt: expires,
      );
    } else {
      fridge.add(catalogItem.copyWith(quantity: packSize, expiresAt: expires));
    }
    await saveFridge(fridge);
    await save(c);
    return c;
  }

  Future<CharacterModel> wash({required double amount}) async {
    var c = await tick();
    c = c.copyWith(
      needs: c.needs.copyWith(
        cleanliness: c.needs.cleanliness + amount,
      ),
      dirtLevel: (c.dirtLevel - amount).clamp(0, 100),
      mood: (c.mood + amount * 0.3).clamp(0, 100),
    );
    await save(c);
    return c;
  }

  Future<CharacterModel> brushTeeth() async {
    var c = await tick();
    c = c.copyWith(
      needs: c.needs.adjust(NeedType.cleanliness, 10),
      mood: (c.mood + 4).clamp(0, 100),
    );
    await save(c);
    return c;
  }

  Future<CharacterModel> combHair() async {
    var c = await tick();
    c = c.copyWith(
      needs: c.needs.adjust(NeedType.cleanliness, 6),
      mood: (c.mood + 3).clamp(0, 100),
    );
    await save(c);
    return c;
  }

  Future<CharacterModel> useToilet() async {
    var c = await tick();
    c = c.copyWith(
      needs: c.needs.copyWith(toilet: 100),
      mood: (c.mood + 5).clamp(0, 100),
    );
    await save(c);
    return c;
  }

  Future<CharacterModel> sleep({required bool lightsOff}) async {
    if (!lightsOff) throw StateError('Спочатку вимкни світло');
    var c = await tick();
    c = c.copyWith(isSleeping: true);
    await save(c);
    return c;
  }

  Future<CharacterModel> wakeUp({bool tellDream = false}) async {
    var c = await tick();
    c = c.copyWith(
      isSleeping: false,
      needs: c.needs.copyWith(energy: 100),
      mood: (c.mood + 10).clamp(0, 100),
    );
    await save(c);
    return c;
  }

  Future<CharacterModel> playFun(double amount) async {
    var c = await tick();
    c = c.copyWith(
      needs: c.needs.copyWith(
        fun: c.needs.fun + amount,
        energy: c.needs.energy - amount * 0.35,
        hunger: c.needs.hunger - amount * 0.15,
      ),
      mood: (c.mood + amount * 0.4).clamp(0, 100),
    );
    await save(c);
    return c;
  }

  Future<CharacterModel> socialize(double amount) async {
    var c = await tick();
    c = c.copyWith(
      needs: c.needs.adjust(NeedType.social, amount),
      mood: (c.mood + amount * 0.25).clamp(0, 100),
    );
    await save(c);
    return c;
  }

  Future<CharacterModel> addCoins(int regular, {int donate = 0}) async {
    var c = await tick();
    c = c.copyWith(
      coins: c.coins + regular,
      donateCoins: c.donateCoins + donate,
    );
    await save(c);
    return c;
  }

  Future<CharacterModel> spendCoins(int amount) async {
    var c = await tick();
    if (c.coins < amount) throw StateError('Недостатньо коїнів');
    c = c.copyWith(coins: c.coins - amount);
    await save(c);
    return c;
  }

  Future<CharacterModel> exchangeDonateToRegular(int donateAmount) async {
    var c = await tick();
    if (c.donateCoins < donateAmount) {
      throw StateError('Недостатньо донатних коїнів');
    }
    // 1 donate = 50 regular
    c = c.copyWith(
      donateCoins: c.donateCoins - donateAmount,
      coins: c.coins + donateAmount * 50,
    );
    await save(c);
    return c;
  }

  Future<CharacterModel> applyInteraction(InteractionGesture g) async {
    var c = await tick();
    final delta = switch (g) {
      InteractionGesture.pokeForehead => -2.0,
      InteractionGesture.shake => -5.0,
      InteractionGesture.stroke => 8.0,
      InteractionGesture.tap => 2.0,
    };
    c = c.copyWith(
      mood: (c.mood + delta).clamp(0, 100),
      needs: c.needs.adjust(NeedType.social, delta.abs() * 0.4),
    );
    await save(c);
    return c;
  }

  Future<CharacterModel> rename(String name) async {
    var c = await tick();
    c = c.copyWith(name: name.trim());
    await save(c);
    return c;
  }

  Future<CharacterModel> setVoicePath(String path) async {
    var c = await tick();
    c = c.copyWith(voiceSamplePath: path);
    await save(c);
    return c;
  }
}

final characterServiceProvider = Provider<CharacterService>(
  (ref) => CharacterService(ref.watch(timeGuardProvider)),
);
