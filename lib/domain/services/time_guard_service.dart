import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/hive_boxes.dart';
import '../../data/local/secure_store.dart';

/// Anti time-travel guard: stores last trusted server/device time
/// and rejects jumps into the past.
class TimeGuardService {
  TimeGuardService(this._secureStore);

  final SecureStore _secureStore;

  static const _keyLastTrusted = 'last_trusted_epoch_ms';

  /// Returns trusted "now". If device clock went backwards, clamp to last trust.
  Future<DateTime> now() async {
    final deviceNow = DateTime.now();
    final lastMs = HiveBoxes.settings.get(_keyLastTrusted) as int?;
    if (lastMs == null) {
      await _commit(deviceNow);
      return deviceNow;
    }
    final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
    if (deviceNow.isBefore(last.subtract(const Duration(minutes: 2)))) {
      // Suspected time rollback — keep last trusted.
      return last;
    }
    // Soft forward allow; commit.
    await _commit(deviceNow);
    return deviceNow;
  }

  /// Sync against a server timestamp when online.
  Future<DateTime> syncWithServer(DateTime serverTime) async {
    final lastMs = HiveBoxes.settings.get(_keyLastTrusted) as int?;
    if (lastMs != null) {
      final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
      if (serverTime.isBefore(last)) {
        return last;
      }
    }
    await _commit(serverTime);
    await _secureStore.saveServerTimeSalt(serverTime.toIso8601String());
    return serverTime;
  }

  Future<void> _commit(DateTime t) async {
    await HiveBoxes.settings.put(_keyLastTrusted, t.millisecondsSinceEpoch);
  }
}

final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());

final timeGuardProvider = Provider<TimeGuardService>(
  (ref) => TimeGuardService(ref.watch(secureStoreProvider)),
);
