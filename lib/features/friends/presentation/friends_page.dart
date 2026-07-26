import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/services/friends_service.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

class FriendsPage extends ConsumerStatefulWidget {
  const FriendsPage({super.key});

  @override
  ConsumerState<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends ConsumerState<FriendsPage> {
  bool _searching = false;

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);

    return GradientScaffold(
      appBar: AppBar(title: const Text('Друзі')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addDialog(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Додати'),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              onPressed: _searching
                  ? null
                  : () async {
                      setState(() => _searching = true);
                      final nearby = await ref
                          .read(friendsProvider.notifier)
                          .searchNearby();
                      setState(() => _searching = false);
                      if (!context.mounted) return;
                      showModalBottomSheet<void>(
                        context: context,
                        builder: (_) => ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Text(
                              'Поблизу (до 0.5 км)',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            for (final f in nearby)
                              ListTile(
                                title: Text(f.displayName),
                                subtitle: Text(
                                  '${f.characterName} · перс. ${f.characterAge}р · '
                                  'людина ${f.realAge}р · '
                                  '${f.distanceMeters!.toStringAsFixed(0)} м',
                                ),
                                trailing: TextButton(
                                  onPressed: () async {
                                    await ref
                                        .read(friendsProvider.notifier)
                                        .add(
                                          displayName: f.displayName,
                                          characterName: f.characterName,
                                          characterAge: f.characterAge,
                                          realAge: f.realAge,
                                        );
                                    if (context.mounted) Navigator.pop(context);
                                  },
                                  child: const Text('Додати'),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
              icon: _searching
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.near_me),
              label: const Text('Пошук поблизу'),
            ),
          ),
          Expanded(
            child: friends.isEmpty
                ? const Center(child: Text('Поки немає друзів'))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: friends.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final f = friends[i];
                      return Material(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(16),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.brandPeach,
                            child: Text(f.isOnline ? '🟢' : '⚪'),
                          ),
                          title: Text(f.displayName),
                          subtitle: Text(
                            '${f.characterName}: ${f.characterAge}р · '
                            'ти: ${f.realAge}р · оцінка ${f.rating.toStringAsFixed(0)}/10'
                            '${f.hasTempAccess ? ' · тимч. доступ' : ''}',
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              final svc = ref.read(friendsServiceProvider);
                              if (v == 'rate') {
                                await svc.rateFriend(
                                  f.id,
                                  (f.rating % 10) + 1,
                                );
                              } else if (v == 'access') {
                                await svc.grantTempAccess(f.id);
                              } else if (v == 'revoke') {
                                await svc.revokeTempAccess(f.id);
                              } else if (v == 'play') {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Спільна гра: запрошення надіслано',
                                      ),
                                    ),
                                  );
                                }
                              } else if (v == 'chat') {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Спілкування через персонажів…',
                                      ),
                                    ),
                                  );
                                }
                              } else if (v == 'remove') {
                                await svc.removeFriend(f.id);
                              }
                              ref.read(friendsProvider.notifier).refresh();
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'rate',
                                child: Text('Оцінити (1–10)'),
                              ),
                              PopupMenuItem(
                                value: 'access',
                                child: Text('Тимчасовий доступ'),
                              ),
                              PopupMenuItem(
                                value: 'revoke',
                                child: Text('Забрати доступ'),
                              ),
                              PopupMenuItem(
                                value: 'play',
                                child: Text('Спільна гра'),
                              ),
                              PopupMenuItem(
                                value: 'chat',
                                child: Text('Чат персонажів'),
                              ),
                              PopupMenuItem(
                                value: 'remove',
                                child: Text('Видалити'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _addDialog(BuildContext context) {
    final name = TextEditingController();
    final char = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Додати друга'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Імʼя')),
            TextField(
              controller: char,
              decoration: const InputDecoration(labelText: 'Персонаж'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Скасувати')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(friendsProvider.notifier).add(
                    displayName: name.text.trim().isEmpty ? 'Друг' : name.text,
                    characterName:
                        char.text.trim().isEmpty ? 'Малюк' : char.text,
                    characterAge: 6,
                    realAge: 14,
                  );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Додати'),
          ),
        ],
      ),
    );
  }
}
