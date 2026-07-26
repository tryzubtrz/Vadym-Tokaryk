class FriendModel {
  const FriendModel({
    required this.id,
    required this.displayName,
    required this.characterName,
    required this.characterAge,
    required this.realAge,
    required this.rating,
    this.distanceMeters,
    this.hasTempAccess = false,
    this.tempAccessUntil,
    this.isOnline = false,
  });

  final String id;
  final String displayName;
  final String characterName;
  final int characterAge;
  final int realAge;
  final double rating; // 1–10
  final double? distanceMeters;
  final bool hasTempAccess;
  final DateTime? tempAccessUntil;
  final bool isOnline;

  FriendModel copyWith({
    String? id,
    String? displayName,
    String? characterName,
    int? characterAge,
    int? realAge,
    double? rating,
    double? distanceMeters,
    bool? hasTempAccess,
    DateTime? tempAccessUntil,
    bool? isOnline,
  }) {
    return FriendModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      characterName: characterName ?? this.characterName,
      characterAge: characterAge ?? this.characterAge,
      realAge: realAge ?? this.realAge,
      rating: rating ?? this.rating,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      hasTempAccess: hasTempAccess ?? this.hasTempAccess,
      tempAccessUntil: tempAccessUntil ?? this.tempAccessUntil,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'characterName': characterName,
        'characterAge': characterAge,
        'realAge': realAge,
        'rating': rating,
        'distanceMeters': distanceMeters,
        'hasTempAccess': hasTempAccess,
        'tempAccessUntil': tempAccessUntil?.toIso8601String(),
        'isOnline': isOnline,
      };

  factory FriendModel.fromJson(Map<String, dynamic> json) => FriendModel(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        characterName: json['characterName'] as String,
        characterAge: json['characterAge'] as int,
        realAge: json['realAge'] as int,
        rating: (json['rating'] as num).toDouble(),
        distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
        hasTempAccess: json['hasTempAccess'] as bool? ?? false,
        tempAccessUntil: json['tempAccessUntil'] != null
            ? DateTime.parse(json['tempAccessUntil'] as String)
            : null,
        isOnline: json['isOnline'] as bool? ?? false,
      );
}
