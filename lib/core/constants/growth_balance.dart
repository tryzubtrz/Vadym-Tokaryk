import 'app_constants.dart';

abstract final class GrowthBalance {
  static const int baseXp = 1200;
  static const int morningCareXp = 80;
  static const int dayCareXp = 70;
  static const int eveningCareXp = 90;
  static const int dailyQuestionXp = 100;
  static const int miniGameWinXp = 40;
  static const int miniGamePlayXp = 15;
  static const int chatMinuteXp = 8;

  static int xpForAge(int age) {
    final years = (age - AppConstants.startAgeYears).clamp(0, 100);
    var xp = baseXp.toDouble();
    for (var i = 0; i < years; i++) {
      xp *= 1.28;
    }
    if (age >= 20) xp += (age - 19) * 400;
    return xp.round();
  }

  static int photosPerDay(int age) {
    if (age < AppConstants.photoUnlockAge) return 0;
    return (age - AppConstants.photoUnlockAge + 1)
        .clamp(1, AppConstants.maxPhotosPerDay);
  }
}
