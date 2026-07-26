// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'character_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CharacterModelImpl _$$CharacterModelImplFromJson(Map<String, dynamic> json) =>
    _$CharacterModelImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      type: $enumDecode(_$CharacterTypeEnumMap, json['type']),
      ageYears:
          (json['ageYears'] as num?)?.toInt() ?? AppConstants.startAgeYears,
      ageStage: $enumDecode(_$AgeStageEnumMap, json['ageStage']),
      regularCoins: (json['regularCoins'] as num?)?.toInt() ?? 0,
      donateCoins: (json['donateCoins'] as num?)?.toInt() ?? 0,
      growthPoints: (json['growthPoints'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      growthPointsNeeded: (json['growthPointsNeeded'] as num?)?.toInt() ?? 90,
      hunger: (json['hunger'] as num?)?.toDouble() ?? 100,
      cleanliness: (json['cleanliness'] as num?)?.toDouble() ?? 100,
      energy: (json['energy'] as num?)?.toDouble() ?? 100,
      fun: (json['fun'] as num?)?.toDouble() ?? 80,
      social: (json['social'] as num?)?.toDouble() ?? 70,
      toilet: (json['toilet'] as num?)?.toDouble() ?? 90,
      bodyWeight:
          $enumDecodeNullable(_$BodyWeightEnumMap, json['bodyWeight']) ??
          BodyWeight.normal,
      daysWithoutFood: (json['daysWithoutFood'] as num?)?.toInt() ?? 0,
      overfeedStreak: (json['overfeedStreak'] as num?)?.toInt() ?? 0,
      isSleeping: json['isSleeping'] as bool? ?? false,
      iq: (json['iq'] as num?)?.toInt() ?? 100,
      photosToday: (json['photosToday'] as num?)?.toInt() ?? 0,
      photosDayKey: json['photosDayKey'] as String? ?? '',
      hasPet: json['hasPet'] as bool? ?? false,
    );

Map<String, dynamic> _$$CharacterModelImplToJson(
  _$CharacterModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'type': _$CharacterTypeEnumMap[instance.type]!,
  'ageYears': instance.ageYears,
  'ageStage': _$AgeStageEnumMap[instance.ageStage]!,
  'regularCoins': instance.regularCoins,
  'donateCoins': instance.donateCoins,
  'growthPoints': instance.growthPoints,
  'createdAt': instance.createdAt.toIso8601String(),
  'growthPointsNeeded': instance.growthPointsNeeded,
  'hunger': instance.hunger,
  'cleanliness': instance.cleanliness,
  'energy': instance.energy,
  'fun': instance.fun,
  'social': instance.social,
  'toilet': instance.toilet,
  'bodyWeight': _$BodyWeightEnumMap[instance.bodyWeight]!,
  'daysWithoutFood': instance.daysWithoutFood,
  'overfeedStreak': instance.overfeedStreak,
  'isSleeping': instance.isSleeping,
  'iq': instance.iq,
  'photosToday': instance.photosToday,
  'photosDayKey': instance.photosDayKey,
  'hasPet': instance.hasPet,
};

const _$CharacterTypeEnumMap = {
  CharacterType.syryk: 'syryk',
  CharacterType.masya: 'masya',
};

const _$AgeStageEnumMap = {
  AgeStage.child: 'child',
  AgeStage.teen: 'teen',
  AgeStage.youngAdult: 'youngAdult',
  AgeStage.adult: 'adult',
  AgeStage.senior: 'senior',
};

const _$BodyWeightEnumMap = {
  BodyWeight.thin: 'thin',
  BodyWeight.normal: 'normal',
  BodyWeight.chubby: 'chubby',
};

_$UserSessionImpl _$$UserSessionImplFromJson(Map<String, dynamic> json) =>
    _$UserSessionImpl(
      languageCode: json['languageCode'] as String? ?? 'uk',
      email: json['email'] as String?,
      realAge: (json['realAge'] as num?)?.toInt(),
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      morningCareDone: json['morningCareDone'] as bool? ?? false,
      dayCareDone: json['dayCareDone'] as bool? ?? false,
      eveningCareDone: json['eveningCareDone'] as bool? ?? false,
      dayKey: json['dayKey'] as String? ?? '',
      dailyQuestion: json['dailyQuestion'] as String?,
      dailyQuestionAnswered: json['dailyQuestionAnswered'] as bool? ?? false,
    );

Map<String, dynamic> _$$UserSessionImplToJson(_$UserSessionImpl instance) =>
    <String, dynamic>{
      'languageCode': instance.languageCode,
      'email': instance.email,
      'realAge': instance.realAge,
      'onboardingComplete': instance.onboardingComplete,
      'morningCareDone': instance.morningCareDone,
      'dayCareDone': instance.dayCareDone,
      'eveningCareDone': instance.eveningCareDone,
      'dayKey': instance.dayKey,
      'dailyQuestion': instance.dailyQuestion,
      'dailyQuestionAnswered': instance.dailyQuestionAnswered,
    };

_$FoodItemImpl _$$FoodItemImplFromJson(Map<String, dynamic> json) =>
    _$FoodItemImpl(
      id: json['id'] as String,
      nameUk: json['nameUk'] as String,
      emoji: json['emoji'] as String,
      price: (json['price'] as num).toInt(),
      hungerRestore: (json['hungerRestore'] as num).toDouble(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
    );

Map<String, dynamic> _$$FoodItemImplToJson(_$FoodItemImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nameUk': instance.nameUk,
      'emoji': instance.emoji,
      'price': instance.price,
      'hungerRestore': instance.hungerRestore,
      'quantity': instance.quantity,
      'expiresAt': instance.expiresAt?.toIso8601String(),
    };
