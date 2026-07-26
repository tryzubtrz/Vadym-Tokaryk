import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/app_constants.dart';

class SecureStore {
  SecureStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  Future<void> saveAuthToken(String token) =>
      _storage.write(key: AppConstants.keyAuthToken, value: token);

  Future<String?> readAuthToken() =>
      _storage.read(key: AppConstants.keyAuthToken);

  Future<void> clearAuthToken() =>
      _storage.delete(key: AppConstants.keyAuthToken);

  Future<void> savePasswordHash(String hash) =>
      _storage.write(key: AppConstants.keyPasswordHash, value: hash);

  Future<String?> readPasswordHash() =>
      _storage.read(key: AppConstants.keyPasswordHash);

  Future<void> saveServerTimeSalt(String salt) =>
      _storage.write(key: AppConstants.keyServerTimeSalt, value: salt);

  Future<String?> readServerTimeSalt() =>
      _storage.read(key: AppConstants.keyServerTimeSalt);
}
