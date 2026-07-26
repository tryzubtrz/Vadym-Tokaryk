import 'package:flutter_test/flutter_test.dart';
import 'package:mymasya_ai/core/constants/growth_balance.dart';
import 'package:mymasya_ai/data/models/enums.dart';
import 'package:mymasya_ai/features/growth/domain/care_slot_clock.dart';

void main() {
  group('GrowthBalance', () {
    test('xp curve rises with age', () {
      expect(GrowthBalance.xpForAge(5), greaterThan(GrowthBalance.xpForAge(4)));
      expect(GrowthBalance.xpForAge(21), greaterThan(GrowthBalance.xpForAge(19)));
    });

    test('estimated days roughly match design goals', () {
      final early = GrowthBalance.estimatedDays(4);
      expect(early, greaterThan(1.5));
      expect(early, lessThan(4.5));
      expect(GrowthBalance.estimatedDays(25), greaterThan(early));
    });
  });

  group('careSlotForTime', () {
    test('morning / day / evening windows', () {
      expect(careSlotForTime(DateTime(2026, 1, 1, 8)), CareSlot.morning);
      expect(careSlotForTime(DateTime(2026, 1, 1, 14)), CareSlot.day);
      expect(careSlotForTime(DateTime(2026, 1, 1, 21)), CareSlot.evening);
    });
  });
}
