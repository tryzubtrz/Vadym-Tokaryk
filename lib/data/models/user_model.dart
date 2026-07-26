import 'enums.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    required this.realAge,
    required this.countryCode,
    required this.languageCode,
    required this.authProvider,
    required this.createdAt,
    this.twoFactorEnabled = false,
    this.lifeTipsEnabled = true,
    this.notificationsEnabled = true,
  });

  final String id;
  final String email;
  final String displayName;
  final int realAge;
  final String countryCode;
  final String languageCode;
  final AuthProviderType authProvider;
  final DateTime createdAt;
  final bool twoFactorEnabled;
  final bool lifeTipsEnabled;
  final bool notificationsEnabled;

  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    int? realAge,
    String? countryCode,
    String? languageCode,
    AuthProviderType? authProvider,
    DateTime? createdAt,
    bool? twoFactorEnabled,
    bool? lifeTipsEnabled,
    bool? notificationsEnabled,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      realAge: realAge ?? this.realAge,
      countryCode: countryCode ?? this.countryCode,
      languageCode: languageCode ?? this.languageCode,
      authProvider: authProvider ?? this.authProvider,
      createdAt: createdAt ?? this.createdAt,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      lifeTipsEnabled: lifeTipsEnabled ?? this.lifeTipsEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'realAge': realAge,
        'countryCode': countryCode,
        'languageCode': languageCode,
        'authProvider': authProvider.name,
        'createdAt': createdAt.toIso8601String(),
        'twoFactorEnabled': twoFactorEnabled,
        'lifeTipsEnabled': lifeTipsEnabled,
        'notificationsEnabled': notificationsEnabled,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String? ?? '',
        realAge: json['realAge'] as int,
        countryCode: json['countryCode'] as String? ?? 'UA',
        languageCode: json['languageCode'] as String? ?? 'uk',
        authProvider: AuthProviderType.values.firstWhere(
          (e) => e.name == json['authProvider'],
          orElse: () => AuthProviderType.email,
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
        twoFactorEnabled: json['twoFactorEnabled'] as bool? ?? false,
        lifeTipsEnabled: json['lifeTipsEnabled'] as bool? ?? true,
        notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      );
}
