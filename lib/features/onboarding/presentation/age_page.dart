import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

class AgePage extends ConsumerStatefulWidget {
  const AgePage({super.key});

  @override
  ConsumerState<AgePage> createState() => _AgePageState();
}

class _AgePageState extends ConsumerState<AgePage> {
  double _age = 16;

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Text(
              'Скільки тобі років?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Мінімум ${AppConstants.minUserAge} років',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            Text(
              '${_age.round()}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: AppColors.brandCoral,
                  ),
            ),
            Slider(
              value: _age,
              min: AppConstants.minUserAge.toDouble(),
              max: 99,
              divisions: 99 - AppConstants.minUserAge,
              activeColor: AppColors.brandCoral,
              onChanged: (v) => setState(() => _age = v),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () async {
                await ref
                    .read(userProvider.notifier)
                    .setRealAge(_age.round());
                if (context.mounted) context.go('/character');
              },
              child: const Text('Далі'),
            ),
          ],
        ),
      ),
    );
  }
}
