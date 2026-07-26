import '../../../data/models/enums.dart';

/// Visual + AI appearance contract per age stage (Step 2).
class AgeAppearance {
  const AgeAppearance({
    required this.stage,
    required this.minAge,
    required this.maxAgeInclusive,
    required this.modelIdPrefix,
    required this.scale,
    required this.voiceChildModulation,
  });

  final AgeStage stage;
  final int minAge;
  final int maxAgeInclusive;
  final String modelIdPrefix;

  /// Relative on-screen scale (child slightly smaller head-bias feel).
  final double scale;

  /// 1.0 = full child pitch; 0.0 = adult.
  final double voiceChildModulation;

  static const List<AgeAppearance> catalog = [
    AgeAppearance(
      stage: AgeStage.child,
      minAge: 4,
      maxAgeInclusive: 9,
      modelIdPrefix: 'child',
      scale: 0.92,
      voiceChildModulation: 1.0,
    ),
    AgeAppearance(
      stage: AgeStage.teen,
      minAge: 10,
      maxAgeInclusive: 17,
      modelIdPrefix: 'teen',
      scale: 0.96,
      voiceChildModulation: 0.55,
    ),
    AgeAppearance(
      stage: AgeStage.youngAdult,
      minAge: 18,
      maxAgeInclusive: 29,
      modelIdPrefix: 'young_adult',
      scale: 1.0,
      voiceChildModulation: 0.2,
    ),
    AgeAppearance(
      stage: AgeStage.adult,
      minAge: 30,
      maxAgeInclusive: 49,
      modelIdPrefix: 'adult',
      scale: 1.0,
      voiceChildModulation: 0.05,
    ),
    AgeAppearance(
      stage: AgeStage.senior,
      minAge: 50,
      maxAgeInclusive: 120,
      modelIdPrefix: 'senior',
      scale: 1.0,
      voiceChildModulation: 0.0,
    ),
  ];

  static AgeAppearance forAge(int age) {
    final stage = AgeStageX.fromAge(age);
    return catalog.firstWhere((a) => a.stage == stage);
  }

  /// Expected Rive path for [type] at this stage.
  String riveAsset(CharacterType type) =>
      'assets/rive/${modelIdPrefix}_${type.name}.riv';

  /// Fallback cutout sprite key (until Rive ships).
  String fallbackSprite(CharacterType type, {String pose = 'stand'}) {
    if (type == CharacterType.syryk) {
      return 'assets/images/character/syryk_idle_cut.png';
    }
    return switch (pose) {
      'react' || 'happy' || 'wave' =>
        'assets/images/character/masya_react_cut.png',
      'eat' => 'assets/images/character/masya_eat_cut.png',
      'sleep' => 'assets/images/character/masya_sleep_cut.png',
      _ => 'assets/images/character/masya_stand_cut.png',
    };
  }

  bool get showsBeardOption => stage == AgeStage.senior;
}
