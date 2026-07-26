import 'enums.dart';

class FoodItem {
  const FoodItem({
    required this.id,
    required this.nameUk,
    required this.kind,
    required this.hungerRestore,
    required this.priceCoins,
    required this.emoji,
    this.isFavorite = false,
    this.expiresAt,
    this.quantity = 1,
  });

  final String id;
  final String nameUk;
  final FoodKind kind;
  final double hungerRestore;
  final int priceCoins;
  final String emoji;
  final bool isFavorite;
  final DateTime? expiresAt;
  final int quantity;

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  FoodItem copyWith({
    String? id,
    String? nameUk,
    FoodKind? kind,
    double? hungerRestore,
    int? priceCoins,
    String? emoji,
    bool? isFavorite,
    DateTime? expiresAt,
    int? quantity,
  }) {
    return FoodItem(
      id: id ?? this.id,
      nameUk: nameUk ?? this.nameUk,
      kind: kind ?? this.kind,
      hungerRestore: hungerRestore ?? this.hungerRestore,
      priceCoins: priceCoins ?? this.priceCoins,
      emoji: emoji ?? this.emoji,
      isFavorite: isFavorite ?? this.isFavorite,
      expiresAt: expiresAt ?? this.expiresAt,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nameUk': nameUk,
        'kind': kind.name,
        'hungerRestore': hungerRestore,
        'priceCoins': priceCoins,
        'emoji': emoji,
        'isFavorite': isFavorite,
        'expiresAt': expiresAt?.toIso8601String(),
        'quantity': quantity,
      };

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
        id: json['id'] as String,
        nameUk: json['nameUk'] as String,
        kind: FoodKind.values.byName(json['kind'] as String),
        hungerRestore: (json['hungerRestore'] as num).toDouble(),
        priceCoins: json['priceCoins'] as int,
        emoji: json['emoji'] as String? ?? '🍽',
        isFavorite: json['isFavorite'] as bool? ?? false,
        expiresAt: json['expiresAt'] != null
            ? DateTime.parse(json['expiresAt'] as String)
            : null,
        quantity: json['quantity'] as int? ?? 1,
      );
}

/// Catalog of buyable food packs.
class FoodCatalog {
  FoodCatalog._();

  static final List<FoodItem> shop = [
    const FoodItem(
      id: 'apple',
      nameUk: 'Яблуко',
      kind: FoodKind.snack,
      hungerRestore: 12,
      priceCoins: 5,
      emoji: '🍎',
    ),
    const FoodItem(
      id: 'porridge',
      nameUk: 'Каша',
      kind: FoodKind.breakfast,
      hungerRestore: 28,
      priceCoins: 12,
      emoji: '🥣',
    ),
    const FoodItem(
      id: 'soup',
      nameUk: 'Суп',
      kind: FoodKind.lunch,
      hungerRestore: 35,
      priceCoins: 18,
      emoji: '🍲',
    ),
    const FoodItem(
      id: 'sandwich',
      nameUk: 'Бутерброд',
      kind: FoodKind.lunch,
      hungerRestore: 22,
      priceCoins: 10,
      emoji: '🥪',
    ),
    const FoodItem(
      id: 'pasta',
      nameUk: 'Паста',
      kind: FoodKind.dinner,
      hungerRestore: 40,
      priceCoins: 22,
      emoji: '🍝',
    ),
    const FoodItem(
      id: 'cake',
      nameUk: 'Тістечко',
      kind: FoodKind.treat,
      hungerRestore: 15,
      priceCoins: 16,
      emoji: '🧁',
    ),
    const FoodItem(
      id: 'milk',
      nameUk: 'Молоко',
      kind: FoodKind.drink,
      hungerRestore: 10,
      priceCoins: 6,
      emoji: '🥛',
    ),
    const FoodItem(
      id: 'juice',
      nameUk: 'Сік',
      kind: FoodKind.drink,
      hungerRestore: 8,
      priceCoins: 7,
      emoji: '🧃',
    ),
  ];

  static const packSizes = [1, 5, 10, 20];

  static int packPrice(FoodItem item, int packSize) {
    // Small bulk discount for larger packs.
    final discount = switch (packSize) {
      5 => 0.95,
      10 => 0.90,
      20 => 0.82,
      _ => 1.0,
    };
    return (item.priceCoins * packSize * discount).round();
  }
}
