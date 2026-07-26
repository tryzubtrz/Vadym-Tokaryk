import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/pet_model.dart';
import '../../../domain/services/pet_service.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

class PetPage extends ConsumerStatefulWidget {
  const PetPage({super.key});

  @override
  ConsumerState<PetPage> createState() => _PetPageState();
}

class _PetPageState extends ConsumerState<PetPage> {
  String _kind = 'cat';
  final _name = TextEditingController(text: 'Пухнастик');

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String _emoji(String kind) => switch (kind) {
        'dog' => '🐶',
        'bunny' => '🐰',
        'fox' => '🦊',
        _ => '🐱',
      };

  @override
  Widget build(BuildContext context) {
    final character = ref.watch(characterProvider);
    final pet = ref.watch(petServiceProvider).load();

    if (character == null || !character.petUnlocked) {
      return GradientScaffold(
        appBar: AppBar(title: const Text('Пітомець')),
        child: const Center(child: Text('Доступно з 10 років')),
      );
    }

    return GradientScaffold(
      appBar: AppBar(title: const Text('Пітомець')),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: pet == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Обери пітомця (200 коїнів)',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final k in PetModel.availableKinds)
                        ChoiceChip(
                          label: Text('${_emoji(k)} $k'),
                          selected: _kind == k,
                          onSelected: (_) => setState(() => _kind = k),
                        ),
                    ],
                  ),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Імʼя'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await ref.read(petServiceProvider).buy(
                              kind: _kind,
                              name: _name.text.trim(),
                            );
                        await ref.read(characterProvider.notifier).refresh();
                        setState(() {});
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      }
                    },
                    child: const Text('Купити'),
                  ),
                ],
              )
            : Column(
                children: [
                  Text(_emoji(pet.kind), style: const TextStyle(fontSize: 96)),
                  Text(
                    pet.name,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    'Разом із ${character.name} ❤️',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Text('Голод: ${pet.hunger.toStringAsFixed(0)}'),
                  Text('Щастя: ${pet.happiness.toStringAsFixed(0)}'),
                  Text('Енергія: ${pet.energy.toStringAsFixed(0)}'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            await ref.read(petServiceProvider).feed();
                            setState(() {});
                          },
                          child: const Text('Погодувати'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await ref.read(petServiceProvider).play();
                            await ref
                                .read(characterProvider.notifier)
                                .refresh();
                            setState(() {});
                          },
                          child: const Text('Пограти разом'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
