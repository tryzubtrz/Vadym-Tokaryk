import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/growth_balance.dart';
import 'enums.dart';

part 'character_model.freezed.dart';
part 'character_model.g.dart';

@freezed
class CharacterModel with _$CharacterModel {
  const CharacterModel._();

  const factory CharacterModel({
    required String id,
    required String name,
    required CharacterType type,
    @Default(AppConstants.startAgeYears) int ageYears,
    required AgeStage ageStage,
    @Default(0) int regularCoins,
    @Default(0) int donateCoins,
    @Default(0) int growthPoints,
    required DateTime createdAt,
    @Default(90) int growthPointsNeeded,
    @Default(100) double hunger,
    @Default(100) double cleanliness,
    @Default(100) double energy,
    @Default(80) double fun,
    @Default(70) double social,
    @Default(90) double toilet,
    @Default(BodyWeight.normal) BodyWeight bodyWeight,
    @Default(0) int daysWithoutFood,
    @Default(0) int overfeedStreak,
    @Default(false) bool isSleeping,
    @Default(100) int iq,
    @Default(0) int photosToday,
    @Default('') String photosDayKey,
    @Default(false) bool hasPet,
  }) = _CharacterModel;

  factory CharacterModel.fromJson(Map<String, dynamic> json) =>
      _$CharacterModelFromJson(json);

  double get yearProgress => growthPointsNeeded <= 0
      ? 0
      : (growthPoints / growthPointsNeeded).clamp(0.0, 1.0);

  bool get photoUnlocked => ageYears >= AppConstants.photoUnlockAge;
  bool get codeUnlocked => ageYears >= AppConstants.codeUnlockAge;
  bool get petUnlocked => ageYears >= AppConstants.petUnlockAge;

  static CharacterModel create({
    required String id,
    required String name,
    required CharacterType type,
  }) {
    final age = AppConstants.startAgeYears;
    return CharacterModel(
      id: id,
      name: name,
      type: type,
      ageYears: age,
      ageStage: AgeStageX.fromAge(age),
      createdAt: DateTime.now(),
      growthPointsNeeded: GrowthBalance.xpForAge(age),
      regularCoins: 50,
      donateCoins: 5,
    );
  }
}

@freezed
class UserSession with _$UserSession {
  const factory UserSession({
    @Default('uk') String languageCode,
    String? email,
    int? realAge,
    @Default(false) bool onboardingComplete,
    @Default(false) bool morningCareDone,
    @Default(false) bool dayCareDone,
    @Default(false) bool eveningCareDone,
    @Default('') String dayKey,
    String? dailyQuestion,
    @Default(false) bool dailyQuestionAnswered,
  }) = _UserSession;

  factory UserSession.fromJson(Map<String, dynamic> json) =>
      _$UserSessionFromJson(json);
}

@freezed
class FoodItem with _$FoodItem {
  const factory FoodItem({
    required String id,
    required String nameUk,
    required String emoji,
    required int price,
    required double hungerRestore,
    @Default(1) int quantity,
    DateTime? expiresAt,
  }) = _FoodItem;

  factory FoodItem.fromJson(Map<String, dynamic> json) =>
      _$FoodItemFromJson(json);
}
