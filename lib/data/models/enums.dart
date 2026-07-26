/// Character gender / base skin choice.
enum CharacterType {
  syryk, // boy
  masya, // girl
}

extension CharacterTypeX on CharacterType {
  String get displayName => switch (this) {
        CharacterType.syryk => 'Сирик',
        CharacterType.masya => 'Мася',
      };

  bool get isBoy => this == CharacterType.syryk;
}

/// Visual + AI model age stage.
enum AgeStage {
  child, // 4–9
  teen, // 10–17
  youngAdult, // 18–29
  adult, // 30–49
  senior, // 50+
}

extension AgeStageX on AgeStage {
  String get labelUk => switch (this) {
        AgeStage.child => 'Дитячий',
        AgeStage.teen => 'Підлітковий',
        AgeStage.youngAdult => 'Молодий дорослий',
        AgeStage.adult => 'Дорослий',
        AgeStage.senior => 'Старший',
      };

  static AgeStage fromAge(int age) {
    if (age < 10) return AgeStage.child;
    if (age < 18) return AgeStage.teen;
    if (age < 30) return AgeStage.youngAdult;
    if (age < 50) return AgeStage.adult;
    return AgeStage.senior;
  }
}

/// Body weight visual state.
enum BodyShape {
  thin,
  normal,
  plump,
}

/// Care routine slot of the day.
enum CareSlot {
  morning,
  day,
  evening,
}

/// Need meters.
enum NeedType {
  hunger,
  cleanliness,
  energy,
  fun,
  social,
  toilet,
}

/// Auth provider.
enum AuthProviderType {
  email,
  apple,
  google,
}

/// Specialized AI model catalog roles.
enum ModelSpecialty {
  base,
  teacher,
  programmer,
  medicine,
  practitioner,
  storyteller,
  coach,
}

extension ModelSpecialtyX on ModelSpecialty {
  String get labelUk => switch (this) {
        ModelSpecialty.base => 'Базова',
        ModelSpecialty.teacher => 'Учитель',
        ModelSpecialty.programmer => 'Програміст',
        ModelSpecialty.medicine => 'Медицина',
        ModelSpecialty.practitioner => 'Практик',
        ModelSpecialty.storyteller => 'Оповідач',
        ModelSpecialty.coach => 'Тренер',
      };
}

/// Food categories.
enum FoodKind {
  breakfast,
  lunch,
  dinner,
  snack,
  treat,
  drink,
}

/// Mini-game ids.
enum MiniGameId {
  trainRun,
  carRide,
  cloudJump,
  foodCatch,
  rhythm,
  maze,
  piano,
  memory,
  hideToy,
}

/// Character interaction gestures.
enum InteractionGesture {
  pokeForehead,
  shake,
  stroke,
  tap,
}

/// Storage provider kinds.
enum StorageProviderKind {
  local,
  s3,
  nextcloud,
  webdav,
  custom,
}
