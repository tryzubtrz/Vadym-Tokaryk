import 'package:flutter/material.dart';

/// Warm, bright Talking Tom–class palette (own IP: Syryk / Masya).
abstract final class AppColors {
  static const Color coral = Color(0xFFE85D4C);
  static const Color peach = Color(0xFFFFB59A);
  static const Color sky = Color(0xFF5BB8D4);
  static const Color mint = Color(0xFF3DDC84);
  static const Color sun = Color(0xFFF5C542);
  static const Color violet = Color(0xFFAB47BC);
  static const Color ink = Color(0xFF1F2A37);
  static const Color paper = Color(0xFFFFF8F2);
  static const Color roomWarm = Color(0xFFFFE0C2);
  static const Color roomCool = Color(0xFFD4F0FF);

  static const LinearGradient splash = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFE8D6), Color(0xFFFFC9A3), coral],
  );
}
