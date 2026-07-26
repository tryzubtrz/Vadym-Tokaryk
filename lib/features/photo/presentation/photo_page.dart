import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/growth_balance.dart';
import '../../../core/theme/app_colors.dart';
import '../../character/providers/app_providers.dart';

class PhotoPage extends ConsumerWidget {
  const PhotoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(characterProvider);
    if (c == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!c.photoUnlocked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Фото')),
        body: const Center(
          child: Text(
            'Фото-кімната відкривається з 10 років',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
    }
    final max = GrowthBalance.photosPerDay(c.ageYears);
    final used = c.photosDayKey == ref.read(characterProvider.notifier).sessionDayKey()
        ? c.photosToday
        : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Фото студія')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Сьогодні: $used / $max фото',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 12),
            const Text(
              'Генерація/редагування фото (локальний stub). '
              'Фінальні моделі підключимо пізніше.',
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final ok =
                    await ref.read(characterProvider.notifier).usePhotoSlot();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? 'Фото створено (stub)'
                          : 'Ліміт на сьогодні вичерпано',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.photo_camera),
              label: const Text('Зробити фото'),
            ),
            const SizedBox(height: 12),
            Container(
              height: 220,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.peach.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text('Превʼю фото', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
