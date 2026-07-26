import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/enums.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/need_bar.dart';

/// In-app preview of the 25% home-screen widget surface.
/// Native Android/iOS glance widgets can mirror this layout.
class HomeWidgetPreview extends ConsumerWidget {
  const HomeWidgetPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(characterProvider);
    if (c == null) return const SizedBox.shrink();

    return Container(
      height: MediaQuery.of(context).size.height * 0.25,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brandCoral.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                c.name,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const Spacer(),
              Text('${c.age}р · голод ${c.needs.hunger.toStringAsFixed(0)}'),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              NeedBar(
                type: NeedType.hunger,
                value: c.needs.hunger,
                compact: true,
              ),
              NeedBar(
                type: NeedType.cleanliness,
                value: c.needs.cleanliness,
                compact: true,
              ),
              NeedBar(
                type: NeedType.energy,
                value: c.needs.energy,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _quick('🍽'),
              _quick('🛁'),
              _quick('💤'),
              _quick('🎮'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quick(String e) => Expanded(
        child: Center(child: Text(e, style: const TextStyle(fontSize: 22))),
      );
}
