import 'enums.dart';

class AiModelInfo {
  const AiModelInfo({
    required this.id,
    required this.nameUk,
    required this.stage,
    required this.specialty,
    required this.sizeMb,
    required this.isDownloaded,
    required this.isActive,
    this.downloadProgress = 0,
    this.downloadedAt,
  });

  final String id;
  final String nameUk;
  final AgeStage stage;
  final ModelSpecialty specialty;
  final int sizeMb;
  final bool isDownloaded;
  final bool isActive;
  final double downloadProgress;
  final DateTime? downloadedAt;

  AiModelInfo copyWith({
    String? id,
    String? nameUk,
    AgeStage? stage,
    ModelSpecialty? specialty,
    int? sizeMb,
    bool? isDownloaded,
    bool? isActive,
    double? downloadProgress,
    DateTime? downloadedAt,
  }) {
    return AiModelInfo(
      id: id ?? this.id,
      nameUk: nameUk ?? this.nameUk,
      stage: stage ?? this.stage,
      specialty: specialty ?? this.specialty,
      sizeMb: sizeMb ?? this.sizeMb,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isActive: isActive ?? this.isActive,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadedAt: downloadedAt ?? this.downloadedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nameUk': nameUk,
        'stage': stage.name,
        'specialty': specialty.name,
        'sizeMb': sizeMb,
        'isDownloaded': isDownloaded,
        'isActive': isActive,
        'downloadProgress': downloadProgress,
        'downloadedAt': downloadedAt?.toIso8601String(),
      };

  factory AiModelInfo.fromJson(Map<String, dynamic> json) => AiModelInfo(
        id: json['id'] as String,
        nameUk: json['nameUk'] as String,
        stage: AgeStage.values.byName(json['stage'] as String),
        specialty: ModelSpecialty.values.byName(json['specialty'] as String),
        sizeMb: json['sizeMb'] as int,
        isDownloaded: json['isDownloaded'] as bool? ?? false,
        isActive: json['isActive'] as bool? ?? false,
        downloadProgress: (json['downloadProgress'] as num?)?.toDouble() ?? 0,
        downloadedAt: json['downloadedAt'] != null
            ? DateTime.parse(json['downloadedAt'] as String)
            : null,
      );

  /// Catalog of base + specialty models per stage.
  static List<AiModelInfo> catalogFor(AgeStage stage) {
    final base = AiModelInfo(
      id: '${stage.name}_base_v1',
      nameUk: 'Базова модель (${stage.labelUk})',
      stage: stage,
      specialty: ModelSpecialty.base,
      sizeMb: _sizeFor(stage, ModelSpecialty.base),
      isDownloaded: false,
      isActive: false,
    );

    final specialties = ModelSpecialty.values
        .where((s) => s != ModelSpecialty.base)
        .map(
          (s) => AiModelInfo(
            id: '${stage.name}_${s.name}_v1',
            nameUk: '${s.labelUk} (${stage.labelUk})',
            stage: stage,
            specialty: s,
            sizeMb: _sizeFor(stage, s),
            isDownloaded: false,
            isActive: false,
          ),
        )
        .toList();

    return [base, ...specialties];
  }

  static int _sizeFor(AgeStage stage, ModelSpecialty s) {
    final base = switch (stage) {
      AgeStage.child => 180,
      AgeStage.teen => 320,
      AgeStage.youngAdult => 480,
      AgeStage.adult => 520,
      AgeStage.senior => 500,
    };
    return s == ModelSpecialty.base ? base : base + 80;
  }
}
