import 'package:hive_flutter/hive_flutter.dart';

abstract final class HiveBoxes {
  static const session = 'session';
  static const character = 'character';
  static const fridge = 'fridge';
  static const chat = 'chat';
  static const meta = 'meta';

  static Future<void> openAll() async {
    await Future.wait([
      Hive.openBox(session),
      Hive.openBox(character),
      Hive.openBox(fridge),
      Hive.openBox(chat),
      Hive.openBox(meta),
    ]);
  }

  static Box get sessionBox => Hive.box(session);
  static Box get characterBox => Hive.box(character);
  static Box get fridgeBox => Hive.box(fridge);
  static Box get chatBox => Hive.box(chat);
  static Box get metaBox => Hive.box(meta);
}
