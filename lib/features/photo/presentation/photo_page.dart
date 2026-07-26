import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/growth_balance.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/services/photo_service.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

class PhotoPage extends ConsumerStatefulWidget {
  const PhotoPage({super.key});

  @override
  ConsumerState<PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends ConsumerState<PhotoPage> {
  final _prompt = TextEditingController();
  int _remaining = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final left = await ref.read(photoServiceProvider).remainingToday();
    setState(() => _remaining = left);
  }

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final character = ref.watch(characterProvider);
    final gallery = ref.watch(photoServiceProvider).loadGallery();
    if (character == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!character.photoRoomUnlocked) {
      return GradientScaffold(
        appBar: AppBar(title: const Text('Кімната фото')),
        child: const Center(
          child: Text('Відкривається з 10 років персонажа'),
        ),
      );
    }

    final limit = GrowthBalance.photosPerDay(character.age);

    return GradientScaffold(
      appBar: AppBar(title: const Text('Кімната фото')),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ліміт сьогодні: $_remaining / $limit '
              '(зростає з віком до 8)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _prompt,
              decoration: const InputDecoration(
                labelText: 'Опис зображення',
                hintText: 'Мася в саду з повітряними кульками',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            try {
                              await ref
                                  .read(photoServiceProvider)
                                  .generate(prompt: _prompt.text.trim());
                              _prompt.clear();
                              await ref
                                  .read(characterProvider.notifier)
                                  .refresh();
                              await _reload();
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$e')),
                                );
                              }
                            }
                            setState(() => _busy = false);
                          },
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Згенерувати'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          final picker = ImagePicker();
                          final file = await picker.pickImage(
                            source: ImageSource.gallery,
                          );
                          if (file == null) return;
                          setState(() => _busy = true);
                          try {
                            await ref.read(photoServiceProvider).editPhoto(
                                  sourcePath: file.path,
                                  instruction: _prompt.text.trim().isEmpty
                                      ? 'Покращити фото'
                                      : _prompt.text.trim(),
                                );
                            await ref
                                .read(characterProvider.notifier)
                                .refresh();
                            await _reload();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$e')),
                              );
                            }
                          }
                          setState(() => _busy = false);
                        },
                  icon: const Icon(Icons.edit),
                  label: const Text('Редагувати'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Галерея', style: Theme.of(context).textTheme.titleMedium),
            Expanded(
              child: gallery.isEmpty
                  ? const Center(child: Text('Поки немає фото'))
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: gallery.length,
                      itemBuilder: (context, i) {
                        final p = gallery[i];
                        return Container(
                          decoration: BoxDecoration(
                            gradient: AppColors.heroGradient,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.brandCoral.withValues(alpha: 0.3),
                            ),
                          ),
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.isEdit ? '✏️ Редагування' : '✨ Генерація',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Text(
                                  p.prompt,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
