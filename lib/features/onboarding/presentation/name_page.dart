import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/enums.dart';
import '../../../domain/services/ai_model_service.dart';
import '../../../domain/services/auth_service.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import 'character_select_page.dart';

class NamePage extends ConsumerStatefulWidget {
  const NamePage({super.key});

  @override
  ConsumerState<NamePage> createState() => _NamePageState();
}

class _NamePageState extends ConsumerState<NamePage> {
  late final TextEditingController _name;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final type = ref.read(selectedCharacterTypeProvider);
    _name = TextEditingController(text: type.displayName);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = ref.watch(selectedCharacterTypeProvider);

    return GradientScaffold(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Text(
              'Імʼя для ${type.displayName}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Старт: 4 роки · 0 коїнів · дитяча модель',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Імʼя персонажа',
                prefixIcon: Icon(Icons.pets_rounded),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _loading
                  ? null
                  : () async {
                      final name = _name.text.trim();
                      if (name.length < 2) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Імʼя має містити щонайменше 2 літери'),
                          ),
                        );
                        return;
                      }
                      setState(() => _loading = true);
                      ref.read(downloadLabelProvider.notifier).state =
                          'Завантаження дитячої моделі…';
                      ref.read(downloadProgressProvider.notifier).state = 0.2;
                      await ref.read(aiModelServiceProvider).ensureStarterModel();
                      ref.read(downloadProgressProvider.notifier).state = 0.8;
                      await ref.read(characterProvider.notifier).create(
                            name: name,
                            type: type,
                          );
                      await ref
                          .read(authServiceProvider)
                          .setOnboardingComplete(true);
                      ref.read(downloadProgressProvider.notifier).state = 1;
                      ref.read(downloadLabelProvider.notifier).state = null;
                      setState(() => _loading = false);
                      if (context.mounted) context.go('/home');
                    },
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Почати життя!'),
            ),
          ],
        ),
      ),
    );
  }
}
