import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../data/local/hive_boxes.dart';
import '../../data/models/enums.dart';

class StorageHost {
  const StorageHost({
    required this.id,
    required this.name,
    required this.countryCode,
    required this.kind,
    required this.isFree,
    required this.priceLabel,
  });

  final String id;
  final String name;
  final String countryCode;
  final StorageProviderKind kind;
  final bool isFree;
  final String priceLabel;
}

class StorageService {
  StorageService();

  int get usedBytesEstimate {
    // Rough estimate from hive entries count * average size.
    var n = 0;
    for (final box in [
      HiveBoxes.user,
      HiveBoxes.character,
      HiveBoxes.chat,
      HiveBoxes.models,
      HiveBoxes.inventory,
    ]) {
      n += box.length;
    }
    return n * 64 * 1024; // 64KB avg stub
  }

  int get limitBytes {
    final custom = HiveBoxes.settings.get('memory_limit_bytes') as int?;
    return custom ?? AppConstants.defaultMemoryLimitBytes;
  }

  double get usageRatio => usedBytesEstimate / limitBytes;

  bool get shouldWarn => usageRatio >= AppConstants.memoryWarningThreshold;

  Future<void> setLimitBytes(int bytes) async {
    await HiveBoxes.settings.put('memory_limit_bytes', bytes);
  }

  List<StorageHost> hostsForCountry(String countryCode) {
    final all = _allHosts;
    final local = all.where((h) => h.countryCode == countryCode).toList();
    final others = all.where((h) => h.countryCode != countryCode).toList();
    return [...local, ...others];
  }

  Future<void> connectHost(StorageHost host) async {
    await HiveBoxes.settings.put('external_storage', {
      'id': host.id,
      'name': host.name,
      'kind': host.kind.name,
      'connectedAt': DateTime.now().toIso8601String(),
    });
  }

  Map<String, dynamic>? connectedHost() {
    final raw = HiveBoxes.settings.get('external_storage');
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  Future<void> syncNow() async {
    // Placeholder sync — would push memory packet + character snapshot.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    await HiveBoxes.settings
        .put('last_storage_sync', DateTime.now().toIso8601String());
  }

  static const _allHosts = [
    StorageHost(
      id: 'ua_free',
      name: 'Ukraine Cloud Free',
      countryCode: 'UA',
      kind: StorageProviderKind.s3,
      isFree: true,
      priceLabel: '0 ₴ / 2 ГБ',
    ),
    StorageHost(
      id: 'ua_plus',
      name: 'Ukraine Cloud Plus',
      countryCode: 'UA',
      kind: StorageProviderKind.s3,
      isFree: false,
      priceLabel: '99 ₴ / 50 ГБ',
    ),
    StorageHost(
      id: 'eu_next',
      name: 'EU Nextcloud',
      countryCode: 'DE',
      kind: StorageProviderKind.nextcloud,
      isFree: true,
      priceLabel: 'Free tier',
    ),
    StorageHost(
      id: 'us_webdav',
      name: 'WebDAV Global',
      countryCode: 'US',
      kind: StorageProviderKind.webdav,
      isFree: false,
      priceLabel: '\$2.99 / 20 GB',
    ),
    StorageHost(
      id: 'custom',
      name: 'Власний сервер',
      countryCode: 'XX',
      kind: StorageProviderKind.custom,
      isFree: true,
      priceLabel: 'Self-hosted',
    ),
  ];
}

final storageServiceProvider = Provider<StorageService>(
  (ref) => StorageService(),
);
