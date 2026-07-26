import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mymasya_ai/features/auth/providers/onboarding_providers.dart';

void main() {
  test('onboarding step advances without session writes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(onboardingStepProvider), 0);
    container.read(onboardingDraftProvider.notifier).setLanguage('en');
    container.read(onboardingStepProvider.notifier).state = 1;
    expect(container.read(onboardingStepProvider), 1);
    expect(container.read(onboardingDraftProvider).languageCode, 'en');
  });
}
