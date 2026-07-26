enum CharacterType { syryk, masya }

extension CharacterTypeX on CharacterType {
  String get labelUk => switch (this) {
        CharacterType.syryk => 'Сирик',
        CharacterType.masya => 'Мася',
      };

  String get subtitleUk => switch (this) {
        CharacterType.syryk => 'Хлопчик-кіт',
        CharacterType.masya => 'Дівчинка-кішка',
      };

  ColorSeed get seed => switch (this) {
        CharacterType.syryk => ColorSeed.boy,
        CharacterType.masya => ColorSeed.girl,
      };
}

enum ColorSeed { boy, girl }

enum AgeStage { child, teen, youngAdult, adult, senior }

extension AgeStageX on AgeStage {
  String get labelUk => switch (this) {
        AgeStage.child => 'Дитячий',
        AgeStage.teen => 'Підлітковий',
        AgeStage.youngAdult => 'Молодий',
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

enum BodyWeight { thin, normal, chubby }

enum CareSlot { morning, day, evening }
