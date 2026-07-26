import 'package:uuid/uuid.dart';

import '../../../core/constants/growth_balance.dart';
import '../../../core/storage/hive_boxes.dart';
import '../domain/character_model.dart';
import '../domain/enums.dart';

class CharacterRepository {
  CharacterModel? load() {
    final raw = HiveBoxes.characterBox.get('current');
    if (raw is Map) {
      return CharacterModel.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  Future<void> save(CharacterModel c) async {
    await HiveBoxes.characterBox.put('current', c.toJson());
  }

  Future<CharacterModel> create({
    required String name,
    required CharacterType type,
  }) async {
    final c = CharacterModel.create(
      id: const Uuid().v4(),
      name: name.trim(),
      type: type,
    );
    await save(c);
    return c;
  }

  List<FoodItem> loadFridge() {
    final raw = HiveBoxes.fridgeBox.get('items');
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => FoodItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    // starter fridge
    final starter = [
      FoodItem(
        id: 'milk',
        nameUk: 'Молоко',
        emoji: '🥛',
        price: 8,
        hungerRestore: 18,
        quantity: 2,
        expiresAt: DateTime.now().add(const Duration(days: 3)),
      ),
      FoodItem(
        id: 'apple',
        nameUk: 'Яблуко',
        emoji: '🍎',
        price: 5,
        hungerRestore: 12,
        quantity: 3,
        expiresAt: DateTime.now().add(const Duration(days: 5)),
      ),
      FoodItem(
        id: 'soup',
        nameUk: 'Суп',
        emoji: '🍲',
        price: 15,
        hungerRestore: 30,
        quantity: 1,
        expiresAt: DateTime.now().add(const Duration(days: 2)),
      ),
    ];
    saveFridge(starter);
    return starter;
  }

  Future<void> saveFridge(List<FoodItem> items) async {
    await HiveBoxes.fridgeBox.put(
      'items',
      items.map((e) => e.toJson()).toList(),
    );
  }

  UserSession loadSession() {
    final raw = HiveBoxes.sessionBox.get('user');
    if (raw is Map) {
      return UserSession.fromJson(Map<String, dynamic>.from(raw));
    }
    return const UserSession();
  }

  Future<void> saveSession(UserSession s) async {
    await HiveBoxes.sessionBox.put('user', s.toJson());
  }

  Future<CharacterModel> applyGrowth(CharacterModel c, int xp, int coins) async {
    var growth = c.growthPoints + xp;
    var age = c.ageYears;
    var needed = c.growthPointsNeeded;
    var iq = c.iq;
    while (growth >= needed) {
      growth -= needed;
      age += 1;
      needed = GrowthBalance.xpForAge(age);
      iq = (iq + 1).clamp(80, 200);
    }
    final updated = c.copyWith(
      growthPoints: growth,
      growthPointsNeeded: needed,
      ageYears: age,
      ageStage: AgeStageX.fromAge(age),
      iq: iq,
      regularCoins: c.regularCoins + coins,
    );
    await save(updated);
    return updated;
  }
}
