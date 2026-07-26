import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/hive_boxes.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/onboarding_flow.dart';
import '../../auth/providers/onboarding_providers.dart';
import '../../character/domain/enums.dart';
import '../../character/providers/app_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final c = ref.watch(characterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Налаштування')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Мова'),
            subtitle: Text(
              kLanguages
                  .firstWhere(
                    (e) => e.$1 == s.languageCode,
                    orElse: () => ('uk', 'Українська'),
                  )
                  .$2,
            ),
            onTap: () async {
              final code = await showModalBottomSheet<String>(
                context: context,
                builder: (_) => ListView(
                  children: [
                    for (final lang in kLanguages)
                      ListTile(
                        title: Text(lang.$2),
                        onTap: () => Navigator.pop(context, lang.$1),
                      ),
                  ],
                ),
              );
              if (code != null) {
                await ref.read(sessionProvider.notifier).setLanguage(code);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Акаунт'),
            subtitle: Text(s.email ?? 'гість'),
          ),
          ListTile(
            leading: const Icon(Icons.pets),
            title: const Text('Персонаж'),
            subtitle: Text(
              c == null
                  ? '—'
                  : '${c.name} · ${c.ageYears} р · ${c.type.labelUk}',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.photo),
            title: const Text('Фото кімната'),
            onTap: () => context.push('/photo'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Кімната коду'),
            onTap: () => context.push('/code'),
          ),
          ListTile(
            leading: const Icon(Icons.cloud),
            title: const Text('Сховище'),
            subtitle: const Text('Local Hive (S3/Nextcloud — пізніше)'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('Фідбек'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Дякуємо! Фідбек збережено локально')),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: AppColors.coral),
            title: const Text('Скинути прогрес'),
            onTap: () async {
              await HiveBoxes.sessionBox.clear();
              await HiveBoxes.characterBox.clear();
              await HiveBoxes.fridgeBox.clear();
              await HiveBoxes.chatBox.clear();
              ref.read(onboardingStepProvider.notifier).state = 0;
              ref.read(onboardingDraftProvider.notifier).reset();
              ref.invalidate(sessionProvider);
              ref.invalidate(characterProvider);
              if (context.mounted) context.go('/onboarding');
            },
          ),
        ],
      ),
    );
  }
}
