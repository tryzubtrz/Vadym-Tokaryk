import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/memory_packet.dart';
import '../../../domain/services/ai_model_service.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

class ModelsPage extends ConsumerStatefulWidget {
  const ModelsPage({super.key});

  @override
  ConsumerState<ModelsPage> createState() => _ModelsPageState();
}

class _ModelsPageState extends ConsumerState<ModelsPage> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final character = ref.watch(characterProvider);
    final models = ref.watch(aiModelServiceProvider);
    final stage = character?.stage ?? AgeStage.child;
    final catalog = models.catalogForStage(stage);
    final cache = models.loadCache();

    return GradientScaffold(
      appBar: AppBar(title: const Text('Моделі інтелекту')),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Етап: ${stage.labelUk}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            'У кеші максимум 2 моделі. При зміні передається памʼять + голос.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_status != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: ref.watch(downloadProgressProvider),
            ),
            Text(_status!),
          ],
          const SizedBox(height: 12),
          Text('Кеш', style: Theme.of(context).textTheme.titleMedium),
          for (final m in cache)
            ListTile(
              leading: Icon(
                m.isActive ? Icons.check_circle : Icons.sd_storage,
                color: m.isActive ? AppColors.brandMint : null,
              ),
              title: Text(m.nameUk),
              subtitle: Text('${m.sizeMb} МБ · ${m.specialty.labelUk}'),
            ),
          const Divider(),
          Text('Каталог етапу', style: Theme.of(context).textTheme.titleMedium),
          for (final m in catalog)
            ListTile(
              title: Text(m.nameUk),
              subtitle: Text('${m.sizeMb} МБ'),
              trailing: ElevatedButton(
                onPressed: () async {
                  final user = ref.read(userProvider);
                  final c = character;
                  if (c == null) return;
                  setState(() => _status = 'Завантаження ${m.nameUk}…');
                  ref.read(downloadLabelProvider.notifier).state = _status;
                  try {
                    final packet = MemoryPacket(
                      userName: user?.displayName ?? 'Друг',
                      userAge: user?.realAge ?? 12,
                      characterName: c.name,
                      preferences: const [],
                      keyFacts: const [],
                      relationshipTone: 'warm',
                      voiceSamplePath: c.voiceSamplePath,
                    );
                    await models.downloadModel(
                      m,
                      onProgress: (p) {
                        ref.read(downloadProgressProvider.notifier).state = p;
                      },
                    );
                    await models.saveMemory(packet);
                    await ref.read(characterProvider.notifier).refresh();
                    // Update active model id on character
                    final updated = ref.read(characterProvider);
                    if (updated != null) {
                      // character service save via copy
                    }
                    setState(() => _status = 'Готово');
                    ref.read(downloadLabelProvider.notifier).state = null;
                  } catch (e) {
                    setState(() => _status = '$e');
                    ref.read(downloadLabelProvider.notifier).state = null;
                  }
                },
                child: const Text('Завантажити'),
              ),
            ),
        ],
      ),
    );
  }
}
