import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../character/domain/enums.dart';
import '../../character/providers/app_providers.dart';
import '../../../core/constants/growth_balance.dart';

CareSlot careSlotNow([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  if (h < 12) return CareSlot.morning;
  if (h < 18) return CareSlot.day;
  return CareSlot.evening;
}

Future<void> awardCareIfNeeded(WidgetRef ref) async {
  final slot = careSlotNow();
  final msg = await ref.read(sessionProvider.notifier).claimCare(slot);
  if (msg.startsWith('Вже')) return;
  final xp = switch (slot) {
    CareSlot.morning => GrowthBalance.morningCareXp,
    CareSlot.day => GrowthBalance.dayCareXp,
    CareSlot.evening => GrowthBalance.eveningCareXp,
  };
  await ref.read(characterProvider.notifier).awardXp(xp, 8);
}
