import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../data/local/hive_boxes.dart';
import '../../data/local/secure_store.dart';
import '../../data/models/enums.dart';
import '../../data/models/user_model.dart';
import 'time_guard_service.dart';

class AuthResult {
  const AuthResult({
    required this.success,
    this.user,
    this.error,
    this.needsEmailCode = false,
    this.pendingEmail,
  });

  final bool success;
  final UserModel? user;
  final String? error;
  final bool needsEmailCode;
  final String? pendingEmail;
}

/// Local-first auth. Apple/Google are stubbed for client flow until keys exist.
class AuthService {
  AuthService(this._secure, this._time);

  final SecureStore _secure;
  final TimeGuardService _time;
  final _uuid = const Uuid();

  String? _pendingCode;
  String? _pendingEmail;
  String? _pendingPassword;

  UserModel? currentUser() {
    final raw = HiveBoxes.user.get('profile');
    if (raw is Map) {
      return UserModel.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  bool get isLoggedIn => currentUser() != null;

  bool get onboardingComplete =>
      HiveBoxes.settings.get('onboarding_complete', defaultValue: false)
          as bool;

  Future<void> setOnboardingComplete(bool v) async {
    await HiveBoxes.settings.put('onboarding_complete', v);
  }

  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
  }) async {
    if (!_validEmail(email)) {
      return const AuthResult(success: false, error: 'Невірний email');
    }
    if (password.length < 6) {
      return const AuthResult(
        success: false,
        error: 'Пароль має містити щонайменше 6 символів',
      );
    }
    final existing = HiveBoxes.user.get('email_$email');
    if (existing != null) {
      return const AuthResult(success: false, error: 'Email уже зареєстровано');
    }

    _pendingEmail = email.trim().toLowerCase();
    _pendingPassword = password;
    _pendingCode = _generateCode();
    // In production this would be emailed. For offline demo we persist locally.
    await HiveBoxes.settings.put('dev_email_code', _pendingCode);
    return AuthResult(
      success: true,
      needsEmailCode: true,
      pendingEmail: _pendingEmail,
    );
  }

  Future<AuthResult> confirmEmailCode(String code) async {
    if (_pendingEmail == null || _pendingPassword == null) {
      return const AuthResult(success: false, error: 'Немає активного запиту');
    }
    if (code.trim() != _pendingCode) {
      return const AuthResult(success: false, error: 'Невірний код');
    }
    final now = await _time.now();
    final user = UserModel(
      id: _uuid.v4(),
      email: _pendingEmail!,
      displayName: _pendingEmail!.split('@').first,
      realAge: AppConstants.minUserAge,
      countryCode: 'UA',
      languageCode:
          HiveBoxes.settings.get('language', defaultValue: 'uk') as String,
      authProvider: AuthProviderType.email,
      createdAt: now,
    );
    await _persistUser(user, password: _pendingPassword);
    _pendingCode = null;
    _pendingEmail = null;
    _pendingPassword = null;
    return AuthResult(success: true, user: user);
  }

  /// Dev helper: returns last generated code.
  String? peekDevCode() =>
      HiveBoxes.settings.get('dev_email_code') as String?;

  Future<AuthResult> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final key = 'email_${email.trim().toLowerCase()}';
    final stored = HiveBoxes.user.get(key);
    if (stored is! Map) {
      return const AuthResult(success: false, error: 'Користувача не знайдено');
    }
    final hash = await _secure.readPasswordHash();
    final expected = _hash(password);
    if (hash != expected) {
      return const AuthResult(success: false, error: 'Невірний пароль');
    }
    final user = UserModel.fromJson(Map<String, dynamic>.from(stored));
    await HiveBoxes.user.put('profile', user.toJson());
    await _secure.saveAuthToken(_uuid.v4());
    return AuthResult(success: true, user: user);
  }

  Future<AuthResult> loginWithApple() async {
    return _oauthStub(AuthProviderType.apple, 'apple.user@privaterelay.apple');
  }

  Future<AuthResult> loginWithGoogle() async {
    return _oauthStub(AuthProviderType.google, 'user@gmail.com');
  }

  Future<AuthResult> _oauthStub(AuthProviderType provider, String email) async {
    final existing = currentUser();
    if (existing != null) {
      return AuthResult(success: true, user: existing);
    }
    final now = await _time.now();
    final user = UserModel(
      id: _uuid.v4(),
      email: email,
      displayName: provider == AuthProviderType.apple ? 'Apple User' : 'Google User',
      realAge: AppConstants.minUserAge,
      countryCode: 'UA',
      languageCode:
          HiveBoxes.settings.get('language', defaultValue: 'uk') as String,
      authProvider: provider,
      createdAt: now,
    );
    await _persistUser(user);
    return AuthResult(success: true, user: user);
  }

  Future<void> updateRealAge(int age) async {
    final user = currentUser();
    if (user == null) return;
    final updated = user.copyWith(realAge: age);
    await HiveBoxes.user.put('profile', updated.toJson());
  }

  Future<void> updateLanguage(String code) async {
    await HiveBoxes.settings.put('language', code);
    final user = currentUser();
    if (user != null) {
      await HiveBoxes.user.put(
        'profile',
        user.copyWith(languageCode: code).toJson(),
      );
    }
  }

  Future<void> logout() async {
    await _secure.clearAuthToken();
    // Keep local character data; only clear session token.
  }

  Future<void> deleteAccount() async {
    await HiveBoxes.user.clear();
    await HiveBoxes.character.clear();
    await HiveBoxes.inventory.clear();
    await HiveBoxes.friends.clear();
    await HiveBoxes.chat.clear();
    await HiveBoxes.growth.clear();
    await HiveBoxes.models.clear();
    await HiveBoxes.pet.clear();
    await _secure.clearAuthToken();
    await HiveBoxes.settings.put('onboarding_complete', false);
  }

  Future<void> _persistUser(UserModel user, {String? password}) async {
    await HiveBoxes.user.put('profile', user.toJson());
    await HiveBoxes.user.put('email_${user.email}', user.toJson());
    if (password != null) {
      await _secure.savePasswordHash(_hash(password));
    }
    await _secure.saveAuthToken(_uuid.v4());
  }

  String _hash(String password) =>
      sha256.convert(utf8.encode('mymasya_$password')).toString();

  String _generateCode() {
    final r = Random.secure();
    return List.generate(6, (_) => r.nextInt(10)).join();
  }

  bool _validEmail(String e) =>
      RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(e.trim());
}

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(
    ref.watch(secureStoreProvider),
    ref.watch(timeGuardProvider),
  ),
);
