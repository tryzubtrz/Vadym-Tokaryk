import 'package:flutter_test/flutter_test.dart';
import 'package:mymasya_ai/data/models/enums.dart';
import 'package:mymasya_ai/features/character/domain/age_appearance.dart';
import 'package:mymasya_ai/features/character/domain/character_animation_state.dart';

void main() {
  group('AgeAppearance', () {
    test('maps ages to stages and rive asset keys', () {
      expect(AgeAppearance.forAge(4).stage, AgeStage.child);
      expect(AgeAppearance.forAge(9).modelIdPrefix, 'child');
      expect(AgeAppearance.forAge(10).stage, AgeStage.teen);
      expect(AgeAppearance.forAge(18).stage, AgeStage.youngAdult);
      expect(AgeAppearance.forAge(30).stage, AgeStage.adult);
      expect(AgeAppearance.forAge(55).stage, AgeStage.senior);
      expect(
        AgeAppearance.forAge(7).riveAsset(CharacterType.masya),
        'assets/rive/child_masya.riv',
      );
      expect(
        AgeAppearance.forAge(50).riveAsset(CharacterType.syryk),
        'assets/rive/senior_syryk.riv',
      );
    });

    test('senior shows beard option; child scale smaller', () {
      expect(AgeAppearance.forAge(55).showsBeardOption, isTrue);
      expect(AgeAppearance.forAge(8).showsBeardOption, isFalse);
      expect(AgeAppearance.forAge(6).scale, lessThan(1.0));
      expect(AgeAppearance.forAge(25).scale, 1.0);
    });

    test('fallback sprites by pose', () {
      final a = AgeAppearance.forAge(8);
      expect(
        a.fallbackSprite(CharacterType.masya),
        'assets/images/character/masya_stand_cut.png',
      );
      expect(
        a.fallbackSprite(CharacterType.masya, pose: 'eat'),
        'assets/images/character/masya_eat_cut.png',
      );
      expect(
        a.fallbackSprite(CharacterType.syryk, pose: 'react'),
        'assets/images/character/syryk_idle_cut.png',
      );
    });
  });

  group('CharacterAnimPose', () {
    test('sprite keys', () {
      expect(CharacterAnimPose.idle.spriteKey, 'stand');
      expect(CharacterAnimPose.react.spriteKey, 'react');
      expect(CharacterAnimPose.eat.spriteKey, 'eat');
      expect(CharacterAnimPose.sleep.spriteKey, 'sleep');
    });

    test('react window', () {
      final reacting = CharacterAnimationState(
        reactUntil: DateTime.now().add(const Duration(seconds: 1)),
      );
      expect(reacting.isReacting, isTrue);
      expect(reacting.effectivePose, CharacterAnimPose.react);

      final done = CharacterAnimationState(
        pose: CharacterAnimPose.idle,
        reactUntil: DateTime.now().subtract(const Duration(seconds: 1)),
      );
      expect(done.isReacting, isFalse);
      expect(done.effectivePose, CharacterAnimPose.idle);
    });
  });
}
