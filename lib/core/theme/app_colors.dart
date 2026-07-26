import 'package:flutter/material.dart';

/// Talking Tom–inspired warm, friendly palette (own IP: Syryk / Masya).
class AppColors {
  AppColors._();

  static const Color brandCoral = Color(0xFFE85D4C);
  static const Color brandPeach = Color(0xFFFFB59A);
  static const Color brandSky = Color(0xFF5BB8D4);
  static const Color brandMint = Color(0xFF3DDC84);
  static const Color brandSun = Color(0xFFF5C542);
  static const Color brandPurple = Color(0xFFAB47BC);
  static const Color brandInk = Color(0xFF1F2A37);
  static const Color brandPaper = Color(0xFFFFF8F2);

  static const Color hunger = Color(0xFFE53935);
  static const Color cleanliness = Color(0xFF29B6F6);
  static const Color energy = Color(0xFF7B6CF6);
  static const Color fun = Color(0xFFF5C542);
  static const Color social = Color(0xFF3DDC84);
  static const Color toilet = Color(0xFF8D6E63);

  static const Color coins = Color(0xFFF5C542);
  static const Color donateCoins = Color(0xFF5BC0EB);
  static const Color levelRing = Color(0xFFE8B0FF);
  static const Color levelFill = Color(0xFF9C27FF);

  static const LinearGradient livingRoom = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE8F6FF), Color(0xFFD4F0E8), Color(0xFFB8E0C8)],
  );

  static const LinearGradient kitchen = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFF4E8), Color(0xFFFFE0C0), Color(0xFFE8B888)],
  );

  static const LinearGradient bathroom = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE3F6FF), Color(0xFFB8E4F5), Color(0xFF7EC8E0)],
  );

  static const LinearGradient bedroom = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE8D4FF), Color(0xFFB898E0), Color(0xFF6A5A9A)],
  );

  /// Generic soft hero / living default.
  static const LinearGradient heroGradient = livingRoom;

  static const LinearGradient gamesGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8FFF4), Color(0xFFD4F0FF)],
  );
}
