import 'package:flutter_test/flutter_test.dart';
import 'package:mymasya_ai/core/constants/app_constants.dart';
import 'package:mymasya_ai/core/constants/growth_balance.dart';
import 'package:mymasya_ai/features/character/domain/enums.dart';
import 'package:mymasya_ai/features/growth/domain/care_helper.dart';

void main() {
  test('constants', () {
    expect(AppConstants.appName, 'MyMasyaAI');
    expect(AppConstants.startAgeYears, 4);
    expect(AppConstants.minUserAge, 12);
  });

  test('age stages', () {
    expect(AgeStageX.fromAge(4), AgeStage.child);
    expect(AgeStageX.fromAge(10), AgeStage.teen);
    expect(AgeStageX.fromAge(18), AgeStage.youngAdult);
    expect(AgeStageX.fromAge(30), AgeStage.adult);
    expect(AgeStageX.fromAge(50), AgeStage.senior);
  });

  test('growth curve', () {
    expect(GrowthBalance.xpForAge(5), greaterThan(GrowthBalance.xpForAge(4)));
    expect(GrowthBalance.photosPerDay(9), 0);
    expect(GrowthBalance.photosPerDay(10), 1);
  });

  test('care slots by clock', () {
    expect(careSlotNow(DateTime(2026, 1, 1, 9)), CareSlot.morning);
    expect(careSlotNow(DateTime(2026, 1, 1, 15)), CareSlot.day);
    expect(careSlotNow(DateTime(2026, 1, 1, 21)), CareSlot.evening);
  });
}
