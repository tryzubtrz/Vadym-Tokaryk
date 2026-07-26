import 'enums.dart';
import 'needs_model.dart';

class CharacterModel {
  const CharacterModel({
    required this.sequentialId,
    required this.name,
    required this.type,
    required this.age,
    required this.iq,
    required this.growthXp,
    required this.growthXpNeeded,
    required this.needs,
    required this.bodyShape,
    required this.coins,
    required this.donateCoins,
    required this.createdAt,
    required this.lastCaredAt,
    required this.lastFedAt,
    this.daysWithoutFood = 0,
    this.overfeedStreak = 0,
    this.photosToday = 0,
    this.photosDayKey = '',
    this.hasPet = false,
    this.voiceSamplePath,
    this.currentModelId = 'child_base_v1',
    this.specialty = ModelSpecialty.base,
    this.mood = 70,
    this.isSleeping = false,
    this.dirtLevel = 0,
  });

  /// Unique sequential public ID assigned at creation.
  final int sequentialId;
  final String name;
  final CharacterType type;
  final int age;
  final int iq;
  final int growthXp;
  final int growthXpNeeded;
  final NeedsModel needs;
  final BodyShape bodyShape;
  final int coins;
  final int donateCoins;
  final DateTime createdAt;
  final DateTime lastCaredAt;
  final DateTime lastFedAt;
  final int daysWithoutFood;
  final int overfeedStreak;
  final int photosToday;
  final String photosDayKey;
  final bool hasPet;
  final String? voiceSamplePath;
  final String currentModelId;
  final ModelSpecialty specialty;
  final double mood;
  final bool isSleeping;
  final double dirtLevel;

  AgeStage get stage => AgeStageX.fromAge(age);

  double get yearProgress =>
      growthXpNeeded <= 0 ? 0 : (growthXp / growthXpNeeded).clamp(0.0, 1.0);

  bool get photoRoomUnlocked => age >= 10;
  bool get codeRoomUnlocked => age >= 20;
  bool get petUnlocked => age >= 10;
  bool get hasBeard => type.isBoy && age >= 50;

  CharacterModel copyWith({
    int? sequentialId,
    String? name,
    CharacterType? type,
    int? age,
    int? iq,
    int? growthXp,
    int? growthXpNeeded,
    NeedsModel? needs,
    BodyShape? bodyShape,
    int? coins,
    int? donateCoins,
    DateTime? createdAt,
    DateTime? lastCaredAt,
    DateTime? lastFedAt,
    int? daysWithoutFood,
    int? overfeedStreak,
    int? photosToday,
    String? photosDayKey,
    bool? hasPet,
    String? voiceSamplePath,
    String? currentModelId,
    ModelSpecialty? specialty,
    double? mood,
    bool? isSleeping,
    double? dirtLevel,
  }) {
    return CharacterModel(
      sequentialId: sequentialId ?? this.sequentialId,
      name: name ?? this.name,
      type: type ?? this.type,
      age: age ?? this.age,
      iq: iq ?? this.iq,
      growthXp: growthXp ?? this.growthXp,
      growthXpNeeded: growthXpNeeded ?? this.growthXpNeeded,
      needs: needs ?? this.needs,
      bodyShape: bodyShape ?? this.bodyShape,
      coins: coins ?? this.coins,
      donateCoins: donateCoins ?? this.donateCoins,
      createdAt: createdAt ?? this.createdAt,
      lastCaredAt: lastCaredAt ?? this.lastCaredAt,
      lastFedAt: lastFedAt ?? this.lastFedAt,
      daysWithoutFood: daysWithoutFood ?? this.daysWithoutFood,
      overfeedStreak: overfeedStreak ?? this.overfeedStreak,
      photosToday: photosToday ?? this.photosToday,
      photosDayKey: photosDayKey ?? this.photosDayKey,
      hasPet: hasPet ?? this.hasPet,
      voiceSamplePath: voiceSamplePath ?? this.voiceSamplePath,
      currentModelId: currentModelId ?? this.currentModelId,
      specialty: specialty ?? this.specialty,
      mood: mood ?? this.mood,
      isSleeping: isSleeping ?? this.isSleeping,
      dirtLevel: dirtLevel ?? this.dirtLevel,
    );
  }

  Map<String, dynamic> toJson() => {
        'sequentialId': sequentialId,
        'name': name,
        'type': type.name,
        'age': age,
        'iq': iq,
        'growthXp': growthXp,
        'growthXpNeeded': growthXpNeeded,
        'needs': needs.toJson(),
        'bodyShape': bodyShape.name,
        'coins': coins,
        'donateCoins': donateCoins,
        'createdAt': createdAt.toIso8601String(),
        'lastCaredAt': lastCaredAt.toIso8601String(),
        'lastFedAt': lastFedAt.toIso8601String(),
        'daysWithoutFood': daysWithoutFood,
        'overfeedStreak': overfeedStreak,
        'photosToday': photosToday,
        'photosDayKey': photosDayKey,
        'hasPet': hasPet,
        'voiceSamplePath': voiceSamplePath,
        'currentModelId': currentModelId,
        'specialty': specialty.name,
        'mood': mood,
        'isSleeping': isSleeping,
        'dirtLevel': dirtLevel,
      };

  factory CharacterModel.fromJson(Map<String, dynamic> json) => CharacterModel(
        sequentialId: json['sequentialId'] as int,
        name: json['name'] as String,
        type: CharacterType.values.byName(json['type'] as String),
        age: json['age'] as int,
        iq: json['iq'] as int? ?? 80,
        growthXp: json['growthXp'] as int? ?? 0,
        growthXpNeeded: json['growthXpNeeded'] as int? ?? 1200,
        needs: NeedsModel.fromJson(
          Map<String, dynamic>.from(json['needs'] as Map? ?? {}),
        ),
        bodyShape: BodyShape.values.byName(
          json['bodyShape'] as String? ?? 'normal',
        ),
        coins: json['coins'] as int? ?? 0,
        donateCoins: json['donateCoins'] as int? ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastCaredAt: DateTime.parse(json['lastCaredAt'] as String),
        lastFedAt: DateTime.parse(json['lastFedAt'] as String),
        daysWithoutFood: json['daysWithoutFood'] as int? ?? 0,
        overfeedStreak: json['overfeedStreak'] as int? ?? 0,
        photosToday: json['photosToday'] as int? ?? 0,
        photosDayKey: json['photosDayKey'] as String? ?? '',
        hasPet: json['hasPet'] as bool? ?? false,
        voiceSamplePath: json['voiceSamplePath'] as String?,
        currentModelId: json['currentModelId'] as String? ?? 'child_base_v1',
        specialty: ModelSpecialty.values.byName(
          json['specialty'] as String? ?? 'base',
        ),
        mood: (json['mood'] as num?)?.toDouble() ?? 70,
        isSleeping: json['isSleeping'] as bool? ?? false,
        dirtLevel: (json['dirtLevel'] as num?)?.toDouble() ?? 0,
      );

  factory CharacterModel.create({
    required int sequentialId,
    required String name,
    required CharacterType type,
    required int growthXpNeeded,
  }) {
    final now = DateTime.now();
    return CharacterModel(
      sequentialId: sequentialId,
      name: name,
      type: type,
      age: 4,
      iq: 85,
      growthXp: 0,
      growthXpNeeded: growthXpNeeded,
      needs: const NeedsModel(),
      bodyShape: BodyShape.normal,
      coins: 0,
      donateCoins: 0,
      createdAt: now,
      lastCaredAt: now,
      lastFedAt: now,
      currentModelId: 'child_base_v1',
    );
  }
}
