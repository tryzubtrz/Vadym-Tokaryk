import 'enums.dart';

class GrowthState {
  const GrowthState({
    required this.dateKey,
    this.morningDone = false,
    this.dayDone = false,
    this.eveningDone = false,
    this.dailyQuestionAsked = false,
    this.dailyQuestionAnswered = false,
    this.dailyQuestionDeadline,
    this.dailyQuestionText,
    this.chatMinutesToday = 0,
    this.gamesPlayedToday = 0,
  });

  final String dateKey;
  final bool morningDone;
  final bool dayDone;
  final bool eveningDone;
  final bool dailyQuestionAsked;
  final bool dailyQuestionAnswered;
  final DateTime? dailyQuestionDeadline;
  final String? dailyQuestionText;
  final int chatMinutesToday;
  final int gamesPlayedToday;

  bool careDone(CareSlot slot) => switch (slot) {
        CareSlot.morning => morningDone,
        CareSlot.day => dayDone,
        CareSlot.evening => eveningDone,
      };

  GrowthState copyWith({
    String? dateKey,
    bool? morningDone,
    bool? dayDone,
    bool? eveningDone,
    bool? dailyQuestionAsked,
    bool? dailyQuestionAnswered,
    DateTime? dailyQuestionDeadline,
    String? dailyQuestionText,
    int? chatMinutesToday,
    int? gamesPlayedToday,
  }) {
    return GrowthState(
      dateKey: dateKey ?? this.dateKey,
      morningDone: morningDone ?? this.morningDone,
      dayDone: dayDone ?? this.dayDone,
      eveningDone: eveningDone ?? this.eveningDone,
      dailyQuestionAsked: dailyQuestionAsked ?? this.dailyQuestionAsked,
      dailyQuestionAnswered:
          dailyQuestionAnswered ?? this.dailyQuestionAnswered,
      dailyQuestionDeadline:
          dailyQuestionDeadline ?? this.dailyQuestionDeadline,
      dailyQuestionText: dailyQuestionText ?? this.dailyQuestionText,
      chatMinutesToday: chatMinutesToday ?? this.chatMinutesToday,
      gamesPlayedToday: gamesPlayedToday ?? this.gamesPlayedToday,
    );
  }

  Map<String, dynamic> toJson() => {
        'dateKey': dateKey,
        'morningDone': morningDone,
        'dayDone': dayDone,
        'eveningDone': eveningDone,
        'dailyQuestionAsked': dailyQuestionAsked,
        'dailyQuestionAnswered': dailyQuestionAnswered,
        'dailyQuestionDeadline': dailyQuestionDeadline?.toIso8601String(),
        'dailyQuestionText': dailyQuestionText,
        'chatMinutesToday': chatMinutesToday,
        'gamesPlayedToday': gamesPlayedToday,
      };

  factory GrowthState.fromJson(Map<String, dynamic> json) => GrowthState(
        dateKey: json['dateKey'] as String,
        morningDone: json['morningDone'] as bool? ?? false,
        dayDone: json['dayDone'] as bool? ?? false,
        eveningDone: json['eveningDone'] as bool? ?? false,
        dailyQuestionAsked: json['dailyQuestionAsked'] as bool? ?? false,
        dailyQuestionAnswered: json['dailyQuestionAnswered'] as bool? ?? false,
        dailyQuestionDeadline: json['dailyQuestionDeadline'] != null
            ? DateTime.parse(json['dailyQuestionDeadline'] as String)
            : null,
        dailyQuestionText: json['dailyQuestionText'] as String?,
        chatMinutesToday: json['chatMinutesToday'] as int? ?? 0,
        gamesPlayedToday: json['gamesPlayedToday'] as int? ?? 0,
      );

  factory GrowthState.today() {
    final now = DateTime.now();
    final key =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return GrowthState(dateKey: key);
  }
}
