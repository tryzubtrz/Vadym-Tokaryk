import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/growth_balance.dart';
import '../../../core/theme/app_colors.dart';
import '../../character/domain/enums.dart';
import '../../character/providers/app_providers.dart';

Future<void> showGrowthSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const GrowthSheet(),
  );
}

class GrowthSheet extends ConsumerWidget {
  const GrowthSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(characterProvider);
    final s = ref.watch(sessionProvider);
    if (c == null) return const SizedBox(height: 120);

    bool done(CareSlot slot) => switch (slot) {
          CareSlot.morning => s.morningCareDone,
          CareSlot.day => s.dayCareDone,
          CareSlot.evening => s.eveningCareDone,
        };

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${c.name} · ${c.ageYears} р · IQ ${c.iq}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          Text('Етап: ${c.ageStage.labelUk}'),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: c.yearProgress.clamp(0.02, 1),
            minHeight: 12,
            borderRadius: BorderRadius.circular(8),
            color: AppColors.coral,
            backgroundColor: Colors.black12,
          ),
          const SizedBox(height: 6),
          Text('${c.growthPoints}/${c.growthPointsNeeded} XP'),
          const SizedBox(height: 14),
          const Text(
            'Догляд сьогодні',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final slot in CareSlot.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            done(slot) ? AppColors.mint : AppColors.coral,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: done(slot)
                          ? null
                          : () async {
                              final claim = await ref
                                  .read(sessionProvider.notifier)
                                  .claimCare(slot);
                              if (claim.startsWith('Вже')) return;
                              final xp = switch (slot) {
                                CareSlot.morning => GrowthBalance.morningCareXp,
                                CareSlot.day => GrowthBalance.dayCareXp,
                                CareSlot.evening => GrowthBalance.eveningCareXp,
                              };
                              final msg = await ref
                                  .read(characterProvider.notifier)
                                  .awardXp(xp, 8);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(msg)),
                                );
                              }
                            },
                      child: Text(
                        switch (slot) {
                          CareSlot.morning => 'Ранок',
                          CareSlot.day => 'День',
                          CareSlot.evening => 'Вечір',
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
