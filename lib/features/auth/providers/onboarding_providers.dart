import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../character/domain/enums.dart';

/// Survives widget remounts (router refresh / parent rebuild).
final onboardingStepProvider = StateProvider<int>((ref) => 0);

final onboardingDraftProvider =
    StateNotifierProvider<OnboardingDraftNotifier, OnboardingDraft>((ref) {
  return OnboardingDraftNotifier();
});

class OnboardingDraft {
  const OnboardingDraft({
    this.languageCode = 'uk',
    this.email = '',
    this.password = '',
    this.realAge,
    this.characterType,
    this.characterName = '',
  });

  final String languageCode;
  final String email;
  final String password;
  final int? realAge;
  final CharacterType? characterType;
  final String characterName;

  OnboardingDraft copyWith({
    String? languageCode,
    String? email,
    String? password,
    int? realAge,
    CharacterType? characterType,
    String? characterName,
  }) {
    return OnboardingDraft(
      languageCode: languageCode ?? this.languageCode,
      email: email ?? this.email,
      password: password ?? this.password,
      realAge: realAge ?? this.realAge,
      characterType: characterType ?? this.characterType,
      characterName: characterName ?? this.characterName,
    );
  }
}

class OnboardingDraftNotifier extends StateNotifier<OnboardingDraft> {
  OnboardingDraftNotifier() : super(const OnboardingDraft());

  void setLanguage(String code) =>
      state = state.copyWith(languageCode: code);

  void setAccount(String email, String password) =>
      state = state.copyWith(email: email, password: password);

  void setRealAge(int age) => state = state.copyWith(realAge: age);

  void setType(CharacterType type) =>
      state = state.copyWith(characterType: type);

  void setName(String name) => state = state.copyWith(characterName: name);

  void reset() => state = const OnboardingDraft();
}
