/// Important memory transferred between AI models on age-stage change.
class MemoryPacket {
  const MemoryPacket({
    required this.userName,
    required this.userAge,
    required this.characterName,
    required this.preferences,
    required this.keyFacts,
    required this.relationshipTone,
    this.voiceSamplePath,
  });

  final String userName;
  final int userAge;
  final String characterName;
  final List<String> preferences;
  final List<String> keyFacts;
  final String relationshipTone;
  final String? voiceSamplePath;

  Map<String, dynamic> toJson() => {
        'userName': userName,
        'userAge': userAge,
        'characterName': characterName,
        'preferences': preferences,
        'keyFacts': keyFacts,
        'relationshipTone': relationshipTone,
        'voiceSamplePath': voiceSamplePath,
      };

  factory MemoryPacket.fromJson(Map<String, dynamic> json) => MemoryPacket(
        userName: json['userName'] as String,
        userAge: json['userAge'] as int,
        characterName: json['characterName'] as String,
        preferences: List<String>.from(json['preferences'] as List? ?? []),
        keyFacts: List<String>.from(json['keyFacts'] as List? ?? []),
        relationshipTone: json['relationshipTone'] as String? ?? 'friendly',
        voiceSamplePath: json['voiceSamplePath'] as String?,
      );
}
