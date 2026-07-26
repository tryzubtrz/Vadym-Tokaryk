class PetModel {
  const PetModel({
    required this.id,
    required this.name,
    required this.kind,
    required this.hunger,
    required this.happiness,
    required this.energy,
    required this.boughtAt,
  });

  final String id;
  final String name;
  final String kind; // cat, dog, bunny, fox
  final double hunger;
  final double happiness;
  final double energy;
  final DateTime boughtAt;

  PetModel copyWith({
    String? id,
    String? name,
    String? kind,
    double? hunger,
    double? happiness,
    double? energy,
    DateTime? boughtAt,
  }) {
    return PetModel(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      hunger: (hunger ?? this.hunger).clamp(0, 100),
      happiness: (happiness ?? this.happiness).clamp(0, 100),
      energy: (energy ?? this.energy).clamp(0, 100),
      boughtAt: boughtAt ?? this.boughtAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind,
        'hunger': hunger,
        'happiness': happiness,
        'energy': energy,
        'boughtAt': boughtAt.toIso8601String(),
      };

  factory PetModel.fromJson(Map<String, dynamic> json) => PetModel(
        id: json['id'] as String,
        name: json['name'] as String,
        kind: json['kind'] as String,
        hunger: (json['hunger'] as num).toDouble(),
        happiness: (json['happiness'] as num).toDouble(),
        energy: (json['energy'] as num).toDouble(),
        boughtAt: DateTime.parse(json['boughtAt'] as String),
      );

  static const availableKinds = ['cat', 'dog', 'bunny', 'fox'];
  static const buyCostGrowthXp = 500;
}
