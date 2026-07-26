import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/growth_balance.dart';
import '../../data/local/hive_boxes.dart';
import 'character_service.dart';
import 'time_guard_service.dart';

class PhotoEntry {
  const PhotoEntry({
    required this.id,
    required this.prompt,
    required this.createdAt,
    this.localPath,
    this.isEdit = false,
  });

  final String id;
  final String prompt;
  final DateTime createdAt;
  final String? localPath;
  final bool isEdit;

  Map<String, dynamic> toJson() => {
        'id': id,
        'prompt': prompt,
        'createdAt': createdAt.toIso8601String(),
        'localPath': localPath,
        'isEdit': isEdit,
      };

  factory PhotoEntry.fromJson(Map<String, dynamic> json) => PhotoEntry(
        id: json['id'] as String,
        prompt: json['prompt'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        localPath: json['localPath'] as String?,
        isEdit: json['isEdit'] as bool? ?? false,
      );
}

class PhotoService {
  PhotoService(this._character, this._time);

  final CharacterService _character;
  final TimeGuardService _time;
  final _uuid = const Uuid();

  List<PhotoEntry> loadGallery() {
    final raw = HiveBoxes.inventory.get('photos');
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => PhotoEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> _saveGallery(List<PhotoEntry> list) async {
    await HiveBoxes.inventory
        .put('photos', list.map((e) => e.toJson()).toList());
  }

  Future<int> remainingToday() async {
    var c = await _character.tick();
    final now = await _time.now();
    final key =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (c.photosDayKey != key) {
      c = c.copyWith(photosToday: 0, photosDayKey: key);
      await _character.save(c);
    }
    final limit = GrowthBalance.photosPerDay(c.age);
    return (limit - c.photosToday).clamp(0, limit);
  }

  Future<PhotoEntry> generate({required String prompt}) async {
    var c = await _character.tick();
    if (!c.photoRoomUnlocked) {
      throw StateError('Кімната фото відкривається з 10 років');
    }
    final left = await remainingToday();
    if (left <= 0) throw StateError('Денний ліміт фото вичерпано');

    // Simulated generation.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final entry = PhotoEntry(
      id: _uuid.v4(),
      prompt: prompt,
      createdAt: DateTime.now(),
    );
    final gallery = loadGallery()..insert(0, entry);
    await _saveGallery(gallery);
    c = c.copyWith(photosToday: c.photosToday + 1);
    await _character.save(c);
    return entry;
  }

  Future<PhotoEntry> editPhoto({
    required String sourcePath,
    required String instruction,
  }) async {
    var c = await _character.tick();
    if (!c.photoRoomUnlocked) {
      throw StateError('Кімната фото відкривається з 10 років');
    }
    final left = await remainingToday();
    if (left <= 0) throw StateError('Денний ліміт фото вичерпано');
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final entry = PhotoEntry(
      id: _uuid.v4(),
      prompt: instruction,
      createdAt: DateTime.now(),
      localPath: sourcePath,
      isEdit: true,
    );
    final gallery = loadGallery()..insert(0, entry);
    await _saveGallery(gallery);
    c = c.copyWith(photosToday: c.photosToday + 1);
    await _character.save(c);
    return entry;
  }
}

final photoServiceProvider = Provider<PhotoService>(
  (ref) => PhotoService(
    ref.watch(characterServiceProvider),
    ref.watch(timeGuardProvider),
  ),
);
