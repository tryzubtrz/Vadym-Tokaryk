import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/hive_boxes.dart';
import '../../data/models/pet_model.dart';
import 'character_service.dart';

class PetService {
  PetService(this._character);

  final CharacterService _character;
  final _uuid = const Uuid();

  PetModel? load() {
    final raw = HiveBoxes.pet.get('main');
    if (raw is Map) {
      return PetModel.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  Future<void> save(PetModel p) async {
    await HiveBoxes.pet.put('main', p.toJson());
  }

  Future<PetModel> buy({required String kind, required String name}) async {
    final c = _character.load();
    if (c == null || !c.petUnlocked) {
      throw StateError('Пітомець доступний з 10 років');
    }
    if (c.hasPet) throw StateError('Пітомець уже є');
    if (c.growthXp < PetModel.buyCostGrowthXp && c.age < 12) {
      // Allow buy spending coins alternatively
    }
    // Cost: 200 coins
    if (c.coins < 200) throw StateError('Потрібно 200 коїнів');
    await _character.spendCoins(200);
    final pet = PetModel(
      id: _uuid.v4(),
      name: name,
      kind: kind,
      hunger: 80,
      happiness: 80,
      energy: 80,
      boughtAt: DateTime.now(),
    );
    await save(pet);
    final updated = _character.load()!.copyWith(hasPet: true);
    await _character.save(updated);
    return pet;
  }

  Future<PetModel> feed() async {
    final p = load();
    if (p == null) throw StateError('Немає пітомця');
    final updated = p.copyWith(hunger: p.hunger + 30, happiness: p.happiness + 5);
    await save(updated);
    return updated;
  }

  Future<PetModel> play() async {
    final p = load();
    if (p == null) throw StateError('Немає пітомця');
    final updated = p.copyWith(
      happiness: p.happiness + 20,
      energy: p.energy - 15,
      hunger: p.hunger - 8,
    );
    await save(updated);
    await _character.playFun(6);
    return updated;
  }
}

final petServiceProvider = Provider<PetService>(
  (ref) => PetService(ref.watch(characterServiceProvider)),
);
