import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../character/providers/app_providers.dart';

class FriendsPage extends ConsumerWidget {
  const FriendsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(characterProvider);
    final nearby = [
      ('Луна', 0.21, 120),
      ('Барсик', 0.35, 98),
      ('Мурчик', 0.48, 156),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Друзі')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (c != null && c.petUnlocked)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.peach,
                  child: Icon(
                    c.hasPet ? Icons.pets : Icons.add,
                    color: Colors.white,
                  ),
                ),
                title: Text(c.hasPet ? 'Пітомець поряд' : 'Завести пітомця'),
                subtitle: const Text('Доступно з 10 років'),
                onTap: () async {
                  if (!c.hasPet) {
                    await ref.read(characterProvider.notifier).refresh();
                    final cur = ref.read(characterProvider);
                    if (cur != null) {
                      await ref
                          .read(characterRepositoryProvider)
                          .save(cur.copyWith(hasPet: true));
                      await ref.read(characterProvider.notifier).refresh();
                    }
                  }
                },
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'Поруч (≤ 0.5 км) — stub геолокації',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 8),
          for (final f in nearby)
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(f.$1),
                subtitle: Text('${f.$2} км · рейтинг ${f.$3}'),
                trailing: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Запит до ${f.$1} надіслано')),
                    );
                  },
                  child: const Text('Дружити'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
