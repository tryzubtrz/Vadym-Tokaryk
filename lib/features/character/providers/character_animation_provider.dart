import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/enums.dart';
import '../../../shared/providers/app_providers.dart';
import '../domain/character_animation_state.dart';

final characterAnimationProvider = StateNotifierProvider<
    CharacterAnimationNotifier, CharacterAnimationState>((ref) {
  return CharacterAnimationNotifier(ref);
});

class CharacterAnimationNotifier extends StateNotifier<CharacterAnimationState> {
  CharacterAnimationNotifier(this._ref)
      : super(const CharacterAnimationState());

  final Ref _ref;

  void setPose(CharacterAnimPose pose) {
    state = state.copyWith(pose: pose, clearReact: true);
  }

  void setTalking(bool talking) {
    state = state.copyWith(talking: talking);
    _ref.read(characterTalkingProvider.notifier).state = talking;
  }

  Future<void> react(InteractionGesture gesture) async {
    state = state.copyWith(
      lastGesture: gesture,
      reactUntil: DateTime.now().add(const Duration(milliseconds: 700)),
      pose: CharacterAnimPose.react,
    );
    await _ref.read(characterProvider.notifier).interact(gesture);
    // Keep react pose briefly then return to idle/sleep.
    await Future<void>.delayed(const Duration(milliseconds: 720));
    if (!mounted) return;
    final sleeping = _ref.read(characterProvider)?.isSleeping ?? false;
    state = state.copyWith(
      pose: sleeping ? CharacterAnimPose.sleep : CharacterAnimPose.idle,
      clearReact: true,
    );
  }
}
