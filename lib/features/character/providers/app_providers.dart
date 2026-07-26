import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/growth_balance.dart';
import '../data/character_repository.dart';
import '../domain/character_model.dart';
import '../domain/enums.dart';

final characterRepositoryProvider = Provider((ref) => CharacterRepository());

final sessionProvider =
    StateNotifierProvider<SessionNotifier, UserSession>((ref) {
  return SessionNotifier(ref.read(characterRepositoryProvider));
});

class SessionNotifier extends StateNotifier<UserSession> {
  SessionNotifier(this._repo) : super(_repo.loadSession());
  final CharacterRepository _repo;

  Future<void> setLanguage(String code) async {
    state = state.copyWith(languageCode: code);
    await _repo.saveSession(state);
  }

  Future<void> setEmail(String email) async {
    state = state.copyWith(email: email.trim());
    await _repo.saveSession(state);
  }

  Future<void> setRealAge(int age) async {
    state = state.copyWith(realAge: age);
    await _repo.saveSession(state);
  }

  Future<void> completeOnboarding() async {
    state = state.copyWith(onboardingComplete: true);
    await _repo.saveSession(state);
  }

  Future<String> claimCare(CareSlot slot) async {
    final today = _todayKey();
    var s = state;
    if (s.dayKey != today) {
      s = s.copyWith(
        dayKey: today,
        morningCareDone: false,
        dayCareDone: false,
        eveningCareDone: false,
        dailyQuestion: null,
        dailyQuestionAnswered: false,
      );
    }
    final done = switch (slot) {
      CareSlot.morning => s.morningCareDone,
      CareSlot.day => s.dayCareDone,
      CareSlot.evening => s.eveningCareDone,
    };
    if (done) return 'Вже отримано сьогодні';
    s = switch (slot) {
      CareSlot.morning => s.copyWith(morningCareDone: true, dayKey: today),
      CareSlot.day => s.copyWith(dayCareDone: true, dayKey: today),
      CareSlot.evening => s.copyWith(eveningCareDone: true, dayKey: today),
    };
    state = s;
    await _repo.saveSession(state);
    final xp = switch (slot) {
      CareSlot.morning => GrowthBalance.morningCareXp,
      CareSlot.day => GrowthBalance.dayCareXp,
      CareSlot.evening => GrowthBalance.eveningCareXp,
    };
    return '+$xp XP';
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }
}

final characterProvider =
    StateNotifierProvider<CharacterNotifier, CharacterModel?>((ref) {
  return CharacterNotifier(ref.read(characterRepositoryProvider));
});

class CharacterNotifier extends StateNotifier<CharacterModel?> {
  CharacterNotifier(this._repo) : super(_repo.load());
  final CharacterRepository _repo;

  Future<void> create({
    required String name,
    required CharacterType type,
  }) async {
    state = await _repo.create(name: name, type: type);
  }

  Future<void> refresh() async => state = _repo.load();

  Future<void> _save(CharacterModel c) async {
    state = c;
    await _repo.save(c);
  }

  Future<String> feed(FoodItem food) async {
    final c = state;
    if (c == null) return 'Немає персонажа';
    var fridge = _repo.loadFridge();
    final idx = fridge.indexWhere((f) => f.id == food.id);
    if (idx < 0 || fridge[idx].quantity <= 0) return 'Немає їжі';

    final item = fridge[idx];
    if (item.quantity == 1) {
      fridge = [...fridge]..removeAt(idx);
    } else {
      fridge = [...fridge]..[idx] = item.copyWith(quantity: item.quantity - 1);
    }
    await _repo.saveFridge(fridge);

    final hunger = (c.hunger + food.hungerRestore).clamp(0, 100);
    var overfeed = c.overfeedStreak;
    var body = c.bodyWeight;
    if (c.hunger > 85) {
      overfeed += 1;
      if (overfeed >= 3) body = BodyWeight.chubby;
    } else {
      overfeed = 0;
    }

    await _save(
      c.copyWith(
        hunger: hunger.toDouble(),
        daysWithoutFood: 0,
        overfeedStreak: overfeed,
        bodyWeight: body,
        fun: (c.fun + 3).clamp(0, 100),
      ),
    );
    return 'Ням-ням!';
  }

  Future<void> buyFood(FoodItem catalogItem, int pack) async {
    final c = state;
    if (c == null) return;
    final cost = catalogItem.price * pack;
    if (c.regularCoins < cost) {
      throw Exception('Недостатньо коїнів');
    }
    var fridge = _repo.loadFridge();
    final idx = fridge.indexWhere((f) => f.id == catalogItem.id);
    if (idx >= 0) {
      final cur = fridge[idx];
      fridge = [...fridge]
        ..[idx] = cur.copyWith(quantity: cur.quantity + pack);
    } else {
      fridge = [
        ...fridge,
        catalogItem.copyWith(
          quantity: pack,
          expiresAt: DateTime.now().add(const Duration(days: 4)),
        ),
      ];
    }
    await _repo.saveFridge(fridge);
    await _save(c.copyWith(regularCoins: c.regularCoins - cost));
  }

  Future<void> wash(double amount) async {
    final c = state;
    if (c == null) return;
    await _save(
      c.copyWith(
        cleanliness: (c.cleanliness + amount).clamp(0, 100),
      ),
    );
  }

  Future<void> brushTeeth() async {
    final c = state;
    if (c == null) return;
    await _save(c.copyWith(cleanliness: (c.cleanliness + 8).clamp(0, 100)));
  }

  Future<void> comb() async {
    final c = state;
    if (c == null) return;
    await _save(c.copyWith(fun: (c.fun + 5).clamp(0, 100)));
  }

  Future<void> toilet() async {
    final c = state;
    if (c == null) return;
    await _save(c.copyWith(toilet: 100));
  }

  Future<void> sleep() async {
    final c = state;
    if (c == null) return;
    await _save(c.copyWith(isSleeping: true, energy: (c.energy + 25).clamp(0, 100)));
  }

  Future<void> wake() async {
    final c = state;
    if (c == null) return;
    await _save(c.copyWith(isSleeping: false, energy: (c.energy + 15).clamp(0, 100)));
  }

  Future<void> tapReact() async {
    final c = state;
    if (c == null) return;
    await _save(
      c.copyWith(
        social: (c.social + 2).clamp(0, 100),
        fun: (c.fun + 2).clamp(0, 100),
      ),
    );
  }

  Future<void> playFun(double amount) async {
    final c = state;
    if (c == null) return;
    await _save(c.copyWith(fun: (c.fun + amount).clamp(0, 100)));
  }

  Future<void> socialize(double amount) async {
    final c = state;
    if (c == null) return;
    await _save(c.copyWith(social: (c.social + amount).clamp(0, 100)));
  }

  Future<String> awardXp(int xp, int coins) async {
    final c = state;
    if (c == null) return '';
    final before = c.ageYears;
    final updated = await _repo.applyGrowth(c, xp, coins);
    state = updated;
    if (updated.ageYears > before) {
      return '${updated.name} тепер має ${updated.ageYears} років!';
    }
    return '+$xp XP, +$coins коїнів';
  }

  Future<void> tickNeeds() async {
    final c = state;
    if (c == null) return;
    // light passive drain for demo feel
    var days = c.daysWithoutFood;
    if (c.hunger < 20) days += 1;
    var body = c.bodyWeight;
    if (days >= AppConstants.daysWithoutFoodThin) body = BodyWeight.thin;
    await _save(
      c.copyWith(
        hunger: (c.hunger - 0.5).clamp(0, 100),
        cleanliness: (c.cleanliness - 0.2).clamp(0, 100),
        energy: c.isSleeping
            ? (c.energy + 0.4).clamp(0, 100)
            : (c.energy - 0.3).clamp(0, 100),
        fun: (c.fun - 0.3).clamp(0, 100),
        social: (c.social - 0.2).clamp(0, 100),
        toilet: (c.toilet - 0.4).clamp(0, 100),
        daysWithoutFood: days,
        bodyWeight: body,
      ),
    );
  }

  Future<bool> usePhotoSlot() async {
    final c = state;
    if (c == null || !c.photoUnlocked) return false;
    final key = sessionDayKey();
    var used = c.photosToday;
    if (c.photosDayKey != key) used = 0;
    final max = GrowthBalance.photosPerDay(c.ageYears);
    if (used >= max) return false;
    await _save(
      c.copyWith(photosToday: used + 1, photosDayKey: key),
    );
    return true;
  }

  String sessionDayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  List<FoodItem> fridge() => _repo.loadFridge();
}

final fridgeProvider = Provider<List<FoodItem>>((ref) {
  ref.watch(characterProvider);
  return ref.watch(characterRepositoryProvider).loadFridge();
});

abstract final class FoodCatalog {
  static final shop = <FoodItem>[
    const FoodItem(
      id: 'milk',
      nameUk: 'Молоко',
      emoji: '🥛',
      price: 8,
      hungerRestore: 18,
    ),
    const FoodItem(
      id: 'apple',
      nameUk: 'Яблуко',
      emoji: '🍎',
      price: 5,
      hungerRestore: 12,
    ),
    const FoodItem(
      id: 'soup',
      nameUk: 'Суп',
      emoji: '🍲',
      price: 15,
      hungerRestore: 30,
    ),
    const FoodItem(
      id: 'cake',
      nameUk: 'Тортик',
      emoji: '🍰',
      price: 25,
      hungerRestore: 22,
    ),
    const FoodItem(
      id: 'fish',
      nameUk: 'Рибка',
      emoji: '🐟',
      price: 18,
      hungerRestore: 28,
    ),
  ];

  static const packSizes = [1, 5, 10, 20];
  static int packPrice(FoodItem item, int pack) => item.price * pack;
}
