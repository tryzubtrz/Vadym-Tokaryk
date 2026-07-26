import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../data/local/hive_boxes.dart';
import '../../data/models/ai_model_info.dart';
import '../../data/models/enums.dart';
import '../../data/models/memory_packet.dart';

/// Manages local AI model cache (max 2), downloads, and stage transitions.
class AiModelService {
  AiModelService();

  List<AiModelInfo> loadCache() {
    final raw = HiveBoxes.models.get('cache');
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => AiModelInfo.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> _saveCache(List<AiModelInfo> list) async {
    await HiveBoxes.models.put('cache', list.map((e) => e.toJson()).toList());
  }

  MemoryPacket? loadMemory() {
    final raw = HiveBoxes.models.get('memory');
    if (raw is Map) {
      return MemoryPacket.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  Future<void> saveMemory(MemoryPacket packet) async {
    await HiveBoxes.models.put('memory', packet.toJson());
  }

  Future<bool> hasInternet() async {
    final r = await Connectivity().checkConnectivity();
    return r.any((e) => e != ConnectivityResult.none);
  }

  /// Simulate download with progress callback.
  Future<AiModelInfo> downloadModel(
    AiModelInfo model, {
    void Function(double progress)? onProgress,
  }) async {
    if (!await hasInternet()) {
      throw StateError('Потрібен інтернет для завантаження моделі');
    }
    // Simulated progressive download.
    for (var i = 1; i <= 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      onProgress?.call(i / 10);
    }
    var cache = loadCache();
    // Deactivate others of same specialty slot conceptually.
    cache = cache
        .map((m) => m.copyWith(isActive: false))
        .where((m) => m.id != model.id)
        .toList();

    final downloaded = model.copyWith(
      isDownloaded: true,
      isActive: true,
      downloadProgress: 1,
      downloadedAt: DateTime.now(),
    );
    cache.insert(0, downloaded);

    // Keep max 2 models.
    while (cache.length > AppConstants.maxCachedModels) {
      final removed = cache.removeLast();
      // Old model deleted from cache.
      await HiveBoxes.models.delete('blob_${removed.id}');
    }
    await _saveCache(cache);
    await HiveBoxes.models.put('blob_${downloaded.id}', {
      'ready': true,
      'stage': downloaded.stage.name,
    });
    return downloaded;
  }

  Future<void> transitionToStage({
    required AgeStage stage,
    required MemoryPacket memory,
    String? voicePath,
  }) async {
    await saveMemory(memory.copyWithVoice(voicePath));
    final base = AiModelInfo.catalogFor(stage).first;
    await downloadModel(base);
  }

  Future<AiModelInfo> switchSpecialty({
    required AgeStage stage,
    required ModelSpecialty specialty,
    required MemoryPacket memory,
  }) async {
    final catalog = AiModelInfo.catalogFor(stage);
    final target = catalog.firstWhere(
      (m) => m.specialty == specialty,
      orElse: () => catalog.first,
    );
    await saveMemory(memory);
    return downloadModel(target);
  }

  List<AiModelInfo> catalogForStage(AgeStage stage) =>
      AiModelInfo.catalogFor(stage);

  AiModelInfo? activeModel() {
    final cache = loadCache();
    return cache.cast<AiModelInfo?>().firstWhere(
          (m) => m?.isActive == true,
          orElse: () => cache.isEmpty ? null : cache.first,
        );
  }

  /// Ensure child base model present after first launch.
  Future<void> ensureStarterModel() async {
    final cache = loadCache();
    if (cache.any((m) => m.id == 'child_base_v1')) return;
    final base = AiModelInfo(
      id: 'child_base_v1',
      nameUk: 'Базова модель (Дитячий)',
      stage: AgeStage.child,
      specialty: ModelSpecialty.base,
      sizeMb: 180,
      isDownloaded: true,
      isActive: true,
      downloadProgress: 1,
      downloadedAt: DateTime.now(),
    );
    await _saveCache([base]);
    await HiveBoxes.models.put('blob_child_base_v1', {'ready': true});
  }
}

extension on MemoryPacket {
  MemoryPacket copyWithVoice(String? path) => MemoryPacket(
        userName: userName,
        userAge: userAge,
        characterName: characterName,
        preferences: preferences,
        keyFacts: keyFacts,
        relationshipTone: relationshipTone,
        voiceSamplePath: path ?? voiceSamplePath,
      );
}

final aiModelServiceProvider = Provider<AiModelService>(
  (ref) => AiModelService(),
);
