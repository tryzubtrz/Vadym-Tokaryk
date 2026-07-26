import 'package:flutter_test/flutter_test.dart';
import 'package:mymasya_ai/core/constants/app_constants.dart';

void main() {
  test('app constants for STAGE 1', () {
    expect(AppConstants.appName, 'MyMasyaAI');
    expect(AppConstants.startAgeYears, 4);
    expect(AppConstants.minUserAge, 12);
  });
}
