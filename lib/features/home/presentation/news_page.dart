import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class NewsPage extends StatelessWidget {
  const NewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Оновлення STAGE full', 'Кухня, ванна, сон, ігри та чат уже в демо.'),
      ('Порада дня', 'Погладь персонажа — це піднімає настрій і соціум.'),
      ('Скоро', 'Онлайн-друзі та справжні Rive-анімації Сирика/Масі.'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Новини')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.coral.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                items[i].$1,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(items[i].$2),
            ],
          ),
        ),
      ),
    );
  }
}
