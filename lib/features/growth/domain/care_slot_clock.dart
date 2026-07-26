import '../../../data/models/enums.dart';

/// Maps wall-clock time to the care routine slot.
CareSlot careSlotForTime(DateTime now) {
  final h = now.hour;
  if (h < 12) return CareSlot.morning;
  if (h < 18) return CareSlot.day;
  return CareSlot.evening;
}
