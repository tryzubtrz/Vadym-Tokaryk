import 'enums.dart';

/// Six vital meters, each 0–100.
class NeedsModel {
  const NeedsModel({
    this.hunger = 70,
    this.cleanliness = 80,
    this.energy = 80,
    this.fun = 60,
    this.social = 50,
    this.toilet = 70,
  });

  final double hunger;
  final double cleanliness;
  final double energy;
  final double fun;
  final double social;
  final double toilet;

  double of(NeedType type) => switch (type) {
        NeedType.hunger => hunger,
        NeedType.cleanliness => cleanliness,
        NeedType.energy => energy,
        NeedType.fun => fun,
        NeedType.social => social,
        NeedType.toilet => toilet,
      };

  NeedsModel copyWith({
    double? hunger,
    double? cleanliness,
    double? energy,
    double? fun,
    double? social,
    double? toilet,
  }) {
    return NeedsModel(
      hunger: _clamp(hunger ?? this.hunger),
      cleanliness: _clamp(cleanliness ?? this.cleanliness),
      energy: _clamp(energy ?? this.energy),
      fun: _clamp(fun ?? this.fun),
      social: _clamp(social ?? this.social),
      toilet: _clamp(toilet ?? this.toilet),
    );
  }

  NeedsModel adjust(NeedType type, double delta) {
    return switch (type) {
      NeedType.hunger => copyWith(hunger: hunger + delta),
      NeedType.cleanliness => copyWith(cleanliness: cleanliness + delta),
      NeedType.energy => copyWith(energy: energy + delta),
      NeedType.fun => copyWith(fun: fun + delta),
      NeedType.social => copyWith(social: social + delta),
      NeedType.toilet => copyWith(toilet: toilet + delta),
    };
  }

  /// Passive decay over [hours] offline/online.
  NeedsModel decay(double hours) {
    return copyWith(
      hunger: hunger - 3.5 * hours,
      cleanliness: cleanliness - 1.2 * hours,
      energy: energy - 2.0 * hours,
      fun: fun - 2.5 * hours,
      social: social - 1.8 * hours,
      toilet: toilet - 4.0 * hours,
    );
  }

  bool get isCritical =>
      hunger < 15 || energy < 15 || cleanliness < 15 || toilet < 10;

  double get average =>
      (hunger + cleanliness + energy + fun + social + toilet) / 6;

  Map<String, dynamic> toJson() => {
        'hunger': hunger,
        'cleanliness': cleanliness,
        'energy': energy,
        'fun': fun,
        'social': social,
        'toilet': toilet,
      };

  factory NeedsModel.fromJson(Map<String, dynamic> json) => NeedsModel(
        hunger: (json['hunger'] as num?)?.toDouble() ?? 70,
        cleanliness: (json['cleanliness'] as num?)?.toDouble() ?? 80,
        energy: (json['energy'] as num?)?.toDouble() ?? 80,
        fun: (json['fun'] as num?)?.toDouble() ?? 60,
        social: (json['social'] as num?)?.toDouble() ?? 50,
        toilet: (json['toilet'] as num?)?.toDouble() ?? 70,
      );

  static double _clamp(double v) => v.clamp(0, 100);
}
