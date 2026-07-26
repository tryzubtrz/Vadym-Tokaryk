/// Global app constants for MyMasyaAI.
class AppConstants {
  AppConstants._();

  static const String appName = 'MyMasyaAI';
  static const String appVersion = '1.0.0';

  /// Character starts at this age.
  static const int startAge = 4;

  /// Real user minimum age.
  static const int minUserAge = 12;

  /// Max models kept in local cache.
  static const int maxCachedModels = 2;

  /// Local memory soft limit (bytes) — 8 GB.
  static const int defaultMemoryLimitBytes = 8 * 1024 * 1024 * 1024;

  /// Warn when storage reaches this fraction.
  static const double memoryWarningThreshold = 0.75;

  /// Nearby friends search radius (meters).
  static const double nearbyFriendsRadiusMeters = 500;

  /// Daily question answer window.
  static const Duration dailyQuestionWindow = Duration(hours: 1);

  /// Days without food before character gets thinner.
  static const int starvationDaysForThin = 5;

  /// Photo room unlock age.
  static const int photoRoomUnlockAge = 10;

  /// Code room unlock age.
  static const int codeRoomUnlockAge = 20;

  /// Pet system unlock age.
  static const int petUnlockAge = 10;

  /// Max photos per day at age 10+.
  static const int maxPhotosPerDay = 8;

  /// Hive box names.
  static const String boxSettings = 'settings';
  static const String boxUser = 'user';
  static const String boxCharacter = 'character';
  static const String boxInventory = 'inventory';
  static const String boxFriends = 'friends';
  static const String boxChat = 'chat';
  static const String boxGrowth = 'growth';
  static const String boxModels = 'models';
  static const String boxNews = 'news';
  static const String boxPet = 'pet';

  /// Secure storage keys.
  static const String keyAuthToken = 'auth_token';
  static const String keyPasswordHash = 'password_hash';
  static const String keyServerTimeSalt = 'server_time_salt';
}
