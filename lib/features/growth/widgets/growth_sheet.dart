import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/growth_balance.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/enums.dart';
import '../../../shared/providers/app_providers.dart';

/// Bottom sheet: XP progress + morning/day/evening care claims.
Future<void> showGrowthSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.brandPaper,
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
    final character = ref.watch(characterProvider);
    final day = ref.watch(growthDayProvider);
    if (character == null) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    }

    final days = GrowthBalance.estimatedDays(character.age);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '${character.name} · ${character.age} років',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.brandInk,
            ),
          ),
          Text(
            'IQ ${character.iq} · етап ${character.stage.labelUk}',
            style: TextStyle(
              color: AppColors.brandInk.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: character.yearProgress.clamp(0.02, 1),
              minHeight: 14,
              backgroundColor: Colors.black12,
              color: AppColors.brandCoral,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${character.growthXp} / ${character.growthXpNeeded} XP'
            ' · ~${days.toStringAsFixed(1)} дн. активного догляду',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 18),
          const Text(
            'Догляд сьогодні',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final slot in CareSlot.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _CareChip(
                      slot: slot,
                      done: day.careDone(slot),
                      onClaim: () async {
                        final msg = await ref
                            .read(growthDayProvider.notifier)
                            .completeCare(slot);
                        await ref.read(characterProvider.notifier).refresh();
                        if (context.mounted && msg != null) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(msg)));
                        }
                      },
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Ігри сьогодні: ${day.gamesPlayedToday} · чат: ${day.chatMinutesToday} хв',
            style: TextStyle(
              color: AppColors.brandInk.withValues(alpha: 0.65),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _CareChip extends StatelessWidget {
  const _CareChip({
    required this.slot,
    required this.done,
    required this.onClaim,
  });

  final CareSlot slot;
  final bool done;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final label = switch (slot) {
      CareSlot.morning => 'Ранок',
      CareSlot.day => 'День',
      CareSlot.evening => 'Вечір',
    };
    final xp = switch (slot) {
      CareSlot.morning => GrowthBalance.morningCareXp,
      CareSlot.day => GrowthBalance.dayCareXp,
      CareSlot.evening => GrowthBalance.eveningCareXp,
    };

    return Material(
      color: done ? AppColors.brandMint.withValues(alpha: 0.25) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: done ? null : onClaim,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            children: [
              Icon(
                done ? Icons.check_circle : Icons.favorite_border,
                color: done ? AppColors.brandMint : AppColors.brandCoral,
              ),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('+$xp XP', style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
