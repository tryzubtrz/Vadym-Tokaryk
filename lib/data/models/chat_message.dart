enum ChatRole { user, character, system }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.isVoice = false,
    this.isLifeTip = false,
  });

  final String id;
  final ChatRole role;
  final String text;
  final DateTime createdAt;
  final bool isVoice;
  final bool isLifeTip;

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'isVoice': isVoice,
        'isLifeTip': isLifeTip,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        role: ChatRole.values.byName(json['role'] as String),
        text: json['text'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        isVoice: json['isVoice'] as bool? ?? false,
        isLifeTip: json['isLifeTip'] as bool? ?? false,
      );
}
