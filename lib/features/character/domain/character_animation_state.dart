import 'package:flutter/foundation.dart';

import '../../../data/models/enums.dart';

/// Runtime animation flags driven by UI + character mood.
@immutable
class CharacterAnimationState {
  const CharacterAnimationState({
    this.pose = CharacterAnimPose.idle,
    this.talking = false,
    this.reactUntil,
    this.lastGesture,
  });

  final CharacterAnimPose pose;
  final bool talking;
  final DateTime? reactUntil;
  final InteractionGesture? lastGesture;

  bool get isReacting {
    final until = reactUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  CharacterAnimPose get effectivePose =>
      isReacting ? CharacterAnimPose.react : pose;

  CharacterAnimationState copyWith({
    CharacterAnimPose? pose,
    bool? talking,
    DateTime? reactUntil,
    InteractionGesture? lastGesture,
    bool clearReact = false,
  }) {
    return CharacterAnimationState(
      pose: pose ?? this.pose,
      talking: talking ?? this.talking,
      reactUntil: clearReact ? null : (reactUntil ?? this.reactUntil),
      lastGesture: lastGesture ?? this.lastGesture,
    );
  }
}

enum CharacterAnimPose {
  idle,
  happy,
  eat,
  sleep,
  sit,
  wave,
  react,
}

extension CharacterAnimPoseX on CharacterAnimPose {
  String get spriteKey => switch (this) {
        CharacterAnimPose.happy ||
        CharacterAnimPose.wave ||
        CharacterAnimPose.react =>
          'react',
        CharacterAnimPose.eat => 'eat',
        CharacterAnimPose.sleep => 'sleep',
        CharacterAnimPose.sit => 'stand',
        CharacterAnimPose.idle => 'stand',
      };
}
