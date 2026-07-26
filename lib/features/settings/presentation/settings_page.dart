import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/services/auth_service.dart';
import '../../../domain/services/character_service.dart';
import '../../../domain/services/growth_service.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final character = ref.watch(characterProvider);

    return GradientScaffold(
      appBar: AppBar(title: const Text('Налаштування')),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _section('Акаунт'),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: Text(user?.email ?? '—'),
            subtitle: Text('Провайдер: ${user?.authProvider.name ?? '-'}'),
          ),
          SwitchListTile(
            value: user?.twoFactorEnabled ?? false,
            title: const Text('2FA (локальний прапорець)'),
            onChanged: (_) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('2FA буде активовано на сервері')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Видалити акаунт'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Видалити все?'),
                  content: const Text('Персонаж і дані будуть стерті локально.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Ні'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Так'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await ref.read(authServiceProvider).deleteAccount();
                if (context.mounted) context.go('/language');
              }
            },
          ),
          _section('Персонаж'),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: Text(character?.name ?? '—'),
            subtitle: Text(
              'ID #${character?.sequentialId} · ${character?.age} років',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final ctrl =
                    TextEditingController(text: character?.name ?? '');
                final name = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Нове імʼя'),
                    content: TextField(controller: ctrl),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Скасувати'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, ctrl.text),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
                if (name != null && name.trim().length >= 2) {
                  await ref.read(characterServiceProvider).rename(name);
                  await ref.read(characterProvider.notifier).refresh();
                }
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.record_voice_over),
            title: const Text('Записати свій голос'),
            subtitle: Text(
              character?.voiceSamplePath == null
                  ? 'Ще не записано · на дитячих етапах модуляція дитяча'
                  : 'Збережено: ${character!.voiceSamplePath}',
            ),
            onTap: () async {
              // Stub local path — real mic capture wired later.
              final path =
                  'voice_${DateTime.now().millisecondsSinceEpoch}.wav';
              await ref.read(characterServiceProvider).setVoicePath(path);
              await ref.read(characterProvider.notifier).refresh();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Голос збережено і передаватиметься моделям'),
                  ),
                );
              }
            },
          ),
          _section('Інтелект і сховище'),
          ListTile(
            leading: const Icon(Icons.psychology_alt),
            title: const Text('Модель інтелекту'),
            subtitle: Text(character?.currentModelId ?? '—'),
            onTap: () => context.push('/models'),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('Памʼять і сховище'),
            onTap: () => context.push('/storage'),
          ),
          _section('Інше'),
          SwitchListTile(
            value: user?.lifeTipsEnabled ?? true,
            title: const Text('Життєві підказки'),
            onChanged: (_) {},
          ),
          SwitchListTile(
            value: user?.notificationsEnabled ?? true,
            title: const Text('Сповіщення'),
            onChanged: (_) {},
          ),
          ListTile(
            leading: const Icon(Icons.monetization_on_outlined),
            title: const Text('Економіка / донат'),
            onTap: () => context.push('/economy'),
          ),
          ListTile(
            leading: const Icon(Icons.ondemand_video),
            title: const Text('Відео за бали'),
            subtitle: const Text('Добровільний перегляд'),
            onTap: () async {
              showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => const AlertDialog(
                  title: Text('Перегляд…'),
                  content: SizedBox(
                    height: 80,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              );
              await Future<void>.delayed(const Duration(seconds: 2));
              final ev = await ref.read(growthServiceProvider).awardVideo();
              await ref.read(characterProvider.notifier).refresh();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '+${ev.xpGained} XP · +${ev.coinsGained} коїнів',
                    ),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text('Звʼязатися з адміністрацією'),
            onTap: () => context.push('/feedback'),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Вийти'),
            onTap: () async {
              await ref.read(authServiceProvider).logout();
              if (context.mounted) context.go('/login');
            },
          ),
          const SizedBox(height: 24),
          Text(
            'MyMasyaAI · розвиток персонажа безкоштовний',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.brandInk.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
        child: Text(
          t,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.brandCoral,
          ),
        ),
      );
}
