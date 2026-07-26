import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/app_constants.dart';

class HiveBoxes {
  HiveBoxes._();

  static late Box settings;
  static late Box user;
  static late Box character;
  static late Box inventory;
  static late Box friends;
  static late Box chat;
  static late Box growth;
  static late Box models;
  static late Box news;
  static late Box pet;

  static Future<void> init() async {
    await Hive.initFlutter();
    settings = await Hive.openBox(AppConstants.boxSettings);
    user = await Hive.openBox(AppConstants.boxUser);
    character = await Hive.openBox(AppConstants.boxCharacter);
    inventory = await Hive.openBox(AppConstants.boxInventory);
    friends = await Hive.openBox(AppConstants.boxFriends);
    chat = await Hive.openBox(AppConstants.boxChat);
    growth = await Hive.openBox(AppConstants.boxGrowth);
    models = await Hive.openBox(AppConstants.boxModels);
    news = await Hive.openBox(AppConstants.boxNews);
    pet = await Hive.openBox(AppConstants.boxPet);
  }
}
