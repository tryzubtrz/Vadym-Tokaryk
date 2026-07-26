import 'app_constants.dart';

/// Growth XP required to advance from [age] to [age + 1].
///
/// Curve goals:
/// - 4→5: ~2–3 days of active play
/// - each next year grows significantly
/// - 20+: ~5+ days of morning/day/evening care
class GrowthBalance {
  GrowthBalance._();

  /// Base XP for the first year jump (4 → 5).
  static const int baseXp = 1200;

  /// XP awards.
  static const int morningCareXp = 80;
  static const int dayCareXp = 70;
  static const int eveningCareXp = 90;
  static const int dailyQuestionXp = 100;
  static const int miniGameWinXp = 40;
  static const int miniGamePlayXp = 15;
  static const int chatMinuteXp = 8;
  static const int chatMinMinutesForXp = 3;
  static const int videoRewardXp = 25;

  /// Coin awards.
  static const int miniGameWinCoins = 12;
  static const int careRoutineCoins = 8;
  static const int dailyQuestionCoins = 15;
  static const int videoRewardCoins = 10;

  /// XP needed to go from [currentAge] → next year.
  static int xpForAge(int currentAge) {
    final yearsFromStart = (currentAge - AppConstants.startAge).clamp(0, 100);
    // Exponential-ish growth: base * (1.28 ^ years) with soft linear boost after 20.
    final exp = (baseXp * _pow(1.28, yearsFromStart)).round();
    if (currentAge >= 20) {
      final lateBoost = (currentAge - 19) * 400;
      return exp + lateBoost;
    }
    return exp;
  }

  /// Approximate active days needed at [age] with full daily care + games.
  static double estimatedDays(int age) {
    const dailyXpEstimate =
        morningCareXp + dayCareXp + eveningCareXp + dailyQuestionXp + 80;
    return xpForAge(age) / dailyXpEstimate;
  }

  /// Photos allowed per day at character [age].
  static int photosPerDay(int age) {
    if (age < AppConstants.photoRoomUnlockAge) return 0;
    final n = age - AppConstants.photoRoomUnlockAge + 1;
    return n.clamp(1, AppConstants.maxPhotosPerDay);
  }

  static double _pow(double base, int exp) {
    var r = 1.0;
    for (var i = 0; i < exp; i++) {
      r *= base;
    }
    return r;
  }
}
