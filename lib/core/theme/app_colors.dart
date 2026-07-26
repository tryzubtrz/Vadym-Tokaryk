import 'package:flutter/material.dart';

/// Brand palette — warm coral + soft sky, not purple-default AI look.
class AppColors {
  AppColors._();

  static const Color brandCoral = Color(0xFFE85D4C);
  static const Color brandPeach = Color(0xFFFFB59A);
  static const Color brandSky = Color(0xFF5BB8D4);
  static const Color brandMint = Color(0xFF6FCFB2);
  static const Color brandSun = Color(0xFFF5C542);
  static const Color brandInk = Color(0xFF1F2A37);
  static const Color brandPaper = Color(0xFFFFF8F2);
  static const Color brandCloud = Color(0xFFE8F4F8);

  static const Color hunger = Color(0xFFE85D4C);
  static const Color cleanliness = Color(0xFF5BB8D4);
  static const Color energy = Color(0xFF7B6CF6);
  static const Color fun = Color(0xFFF5C542);
  static const Color social = Color(0xFF6FCFB2);
  static const Color toilet = Color(0xFFB08968);

  static const Color coins = Color(0xFFF5C542);
  static const Color donateCoins = Color(0xFFE85D4C);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFF1E8),
      Color(0xFFE8F6FA),
      Color(0xFFFFE8E0),
    ],
  );

  static const LinearGradient kitchenGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFF6E8), Color(0xFFFFE0C8)],
  );

  static const LinearGradient bathGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE3F6FF), Color(0xFFB8E4F5)],
  );

  static const LinearGradient bedroomGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF2A2F55), Color(0xFF1A1E38)],
  );

  static const LinearGradient gamesGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8FFF4), Color(0xFFD4F0FF)],
  );
}
