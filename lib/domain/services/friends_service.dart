import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../data/local/hive_boxes.dart';
import '../../data/models/friend_model.dart';

class FriendsService {
  FriendsService();

  final _uuid = const Uuid();
  final _rng = Random();

  List<FriendModel> load() {
    final raw = HiveBoxes.friends.get('list');
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => FriendModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> _save(List<FriendModel> list) async {
    await HiveBoxes.friends.put('list', list.map((e) => e.toJson()).toList());
  }

  Future<FriendModel> addFriend({
    required String displayName,
    required String characterName,
    required int characterAge,
    required int realAge,
  }) async {
    final list = load();
    final f = FriendModel(
      id: _uuid.v4(),
      displayName: displayName,
      characterName: characterName,
      characterAge: characterAge,
      realAge: realAge,
      rating: 5,
      isOnline: _rng.nextBool(),
    );
    list.add(f);
    await _save(list);
    return f;
  }

  Future<void> rateFriend(String id, double rating) async {
    final list = load();
    final idx = list.indexWhere((f) => f.id == id);
    if (idx < 0) return;
    list[idx] = list[idx].copyWith(rating: rating.clamp(1, 10));
    await _save(list);
  }

  Future<void> grantTempAccess(String id, {Duration duration = const Duration(hours: 2)}) async {
    final list = load();
    final idx = list.indexWhere((f) => f.id == id);
    if (idx < 0) return;
    list[idx] = list[idx].copyWith(
      hasTempAccess: true,
      tempAccessUntil: DateTime.now().add(duration),
    );
    await _save(list);
  }

  Future<void> revokeTempAccess(String id) async {
    final list = load();
    final idx = list.indexWhere((f) => f.id == id);
    if (idx < 0) return;
    list[idx] = list[idx].copyWith(hasTempAccess: false, tempAccessUntil: null);
    await _save(list);
  }

  /// Simulated nearby search within 0.5 km.
  Future<List<FriendModel>> searchNearby() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final names = ['Оля', 'Макс', 'Софія', 'Артем', 'Ліза'];
    final chars = ['Бублик', 'Нюша', 'Кекс', 'Пух', 'Зірка'];
    return List.generate(3, (i) {
      final dist = _rng.nextDouble() * AppConstants.nearbyFriendsRadiusMeters;
      return FriendModel(
        id: _uuid.v4(),
        displayName: names[_rng.nextInt(names.length)],
        characterName: chars[_rng.nextInt(chars.length)],
        characterAge: 4 + _rng.nextInt(20),
        realAge: 12 + _rng.nextInt(30),
        rating: 5,
        distanceMeters: dist,
        isOnline: true,
      );
    });
  }

  Future<void> removeFriend(String id) async {
    final list = load()..removeWhere((f) => f.id == id);
    await _save(list);
  }
}

final friendsServiceProvider = Provider<FriendsService>(
  (ref) => FriendsService(),
);
