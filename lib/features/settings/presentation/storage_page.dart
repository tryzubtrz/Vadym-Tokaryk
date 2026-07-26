import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/services/storage_service.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

class StoragePage extends ConsumerWidget {
  const StoragePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);
    final user = ref.watch(userProvider);
    final hosts = storage.hostsForCountry(user?.countryCode ?? 'UA');
    final connected = storage.connectedHost();
    final ratio = storage.usageRatio;

    return GradientScaffold(
      appBar: AppBar(title: const Text('Памʼять і сховище')),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Локальна памʼять',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: ratio.clamp(0, 1),
            minHeight: 12,
            backgroundColor: Colors.black12,
            color: storage.shouldWarn ? Colors.orange : AppColors.brandMint,
          ),
          const SizedBox(height: 6),
          Text(
            '${(ratio * 100).toStringAsFixed(1)}% '
            '${storage.shouldWarn ? '· Увага: понад 75%!' : ''}',
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              await storage.setLimitBytes(storage.limitBytes + 2 * 1024 * 1024 * 1024);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ліміт збільшено на 2 ГБ')),
              );
            },
            child: const Text('Збільшити ліміт (+2 ГБ)'),
          ),
          const Divider(height: 32),
          Text(
            'Зовнішнє сховище',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            'Спочатку хостинги країни користувача (${user?.countryCode ?? 'UA'})',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (connected != null)
            ListTile(
              leading: const Icon(Icons.cloud_done, color: AppColors.brandMint),
              title: Text(connected['name'] as String? ?? 'Підключено'),
              subtitle: Text('Синхр.: ${connected['connectedAt']}'),
              trailing: TextButton(
                onPressed: () async {
                  await storage.syncNow();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Синхронізовано')),
                    );
                  }
                },
                child: const Text('Sync'),
              ),
            ),
          for (final h in hosts)
            ListTile(
              title: Text(h.name),
              subtitle: Text(
                '${h.countryCode} · ${h.kind.name} · ${h.priceLabel}'
                '${h.isFree ? ' · безкоштовно' : ''}',
              ),
              trailing: ElevatedButton(
                onPressed: () async {
                  await storage.connectHost(h);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Підключено: ${h.name}')),
                    );
                  }
                },
                child: const Text('Підключити'),
              ),
            ),
        ],
      ),
    );
  }
}
