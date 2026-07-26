import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color coral = Color(0xFFE85D4C);
  static const Color peach = Color(0xFFFFB59A);
  static const Color sky = Color(0xFF5BB8D4);
  static const Color mint = Color(0xFF3DDC84);
  static const Color sun = Color(0xFFF5C542);
  static const Color violet = Color(0xFFAB47BC);
  static const Color ink = Color(0xFF1F2A37);
  static const Color paper = Color(0xFFFFF8F2);

  static const Color hunger = Color(0xFFE53935);
  static const Color cleanliness = Color(0xFF29B6F6);
  static const Color energy = Color(0xFF7B6CF6);
  static const Color fun = Color(0xFFF5C542);
  static const Color social = Color(0xFF3DDC84);
  static const Color toilet = Color(0xFF8D6E63);

  static const LinearGradient splash = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFE8D6), Color(0xFFFFC9A3), coral],
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
}
