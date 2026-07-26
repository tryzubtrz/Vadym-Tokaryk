import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/growth_balance.dart';
import '../../data/local/hive_boxes.dart';
import '../../data/models/character_model.dart';
import '../../data/models/enums.dart';
import '../../data/models/food_item.dart';
import '../../data/models/user_model.dart';
import 'ai_model_service.dart';
import 'character_service.dart';
import 'time_guard_service.dart';

/// Instant guest session — no registration required for demo / phone preview.
class DemoBootstrap {
  DemoBootstrap(this._character, this._models, this._time);

  final CharacterService _character;
  final AiModelService _models;
  final TimeGuardService _time;

  /// Ensures a playable demo profile exists and returns true if created now.
  Future<bool> ensureDemoReady() async {
    final existing = _character.load();
    if (existing != null &&
        HiveBoxes.settings.get('onboarding_complete', defaultValue: false) ==
            true) {
      return false;
    }

    final now = await _time.now();
    final user = UserModel(
      id: 'demo-guest',
      email: 'demo@mymasya.ai',
      displayName: 'Гість',
      realAge: 18,
      countryCode: 'UA',
      languageCode: 'uk',
      authProvider: AuthProviderType.email,
      createdAt: now,
    );
    await HiveBoxes.user.put('profile', user.toJson());
    await HiveBoxes.settings.put('language', 'uk');

    final id = await _character.nextSequentialId();
    final character = CharacterModel.create(
      sequentialId: id,
      name: 'Мася',
      type: CharacterType.masya,
      growthXpNeeded: GrowthBalance.xpForAge(AppConstants.startAge),
    ).copyWith(
      // Starter coins so kitchen / games feel alive immediately.
      coins: 200,
      donateCoins: 2,
      iq: 90,
      growthXp: 180,
    );
    await _character.save(character);

    // Richer starter fridge for demo.
    final fridge = [
      FoodCatalog.shop.firstWhere((f) => f.id == 'porridge').copyWith(
            quantity: 5,
            expiresAt: now.add(const Duration(days: 5)),
          ),
      FoodCatalog.shop.firstWhere((f) => f.id == 'apple').copyWith(
            quantity: 8,
            expiresAt: now.add(const Duration(days: 7)),
          ),
      FoodCatalog.shop.firstWhere((f) => f.id == 'juice').copyWith(
            quantity: 4,
            expiresAt: now.add(const Duration(days: 4)),
          ),
      FoodCatalog.shop.firstWhere((f) => f.id == 'cake').copyWith(
            quantity: 2,
            expiresAt: now.add(const Duration(days: 3)),
          ),
    ];
    await _character.saveFridge(fridge);
    await _models.ensureStarterModel();
    await HiveBoxes.settings.put('onboarding_complete', true);
    await HiveBoxes.settings.put('demo_mode', true);
    return true;
  }
}

final demoBootstrapProvider = Provider<DemoBootstrap>(
  (ref) => DemoBootstrap(
    ref.watch(characterServiceProvider),
    ref.watch(aiModelServiceProvider),
    ref.watch(timeGuardProvider),
  ),
);
