import 'package:flutter_test/flutter_test.dart';

import 'package:mymasya_ai/core/constants/growth_balance.dart';
import 'package:mymasya_ai/data/models/enums.dart';
import 'package:mymasya_ai/data/models/needs_model.dart';

void main() {
  test('growth XP increases with age', () {
    final a = GrowthBalance.xpForAge(4);
    final b = GrowthBalance.xpForAge(10);
    final c = GrowthBalance.xpForAge(25);
    expect(b, greaterThan(a));
    expect(c, greaterThan(b));
  });

  test('photos per day unlock curve', () {
    expect(GrowthBalance.photosPerDay(9), 0);
    expect(GrowthBalance.photosPerDay(10), 1);
    expect(GrowthBalance.photosPerDay(17), 8);
    expect(GrowthBalance.photosPerDay(30), 8);
  });

  test('age stages', () {
    expect(AgeStageX.fromAge(4), AgeStage.child);
    expect(AgeStageX.fromAge(10), AgeStage.teen);
    expect(AgeStageX.fromAge(18), AgeStage.youngAdult);
    expect(AgeStageX.fromAge(30), AgeStage.adult);
    expect(AgeStageX.fromAge(50), AgeStage.senior);
  });

  test('needs decay and clamp', () {
    const n = NeedsModel(hunger: 10);
    final d = n.decay(10);
    expect(d.hunger, 0);
    expect(d.adjust(NeedType.hunger, 50).hunger, 50);
  });
}
