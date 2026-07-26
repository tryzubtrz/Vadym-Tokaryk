import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/local/hive_boxes.dart';
import 'domain/services/demo_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await HiveBoxes.init();

  // Demo / phone preview: skip registration and land on home.
  final container = ProviderContainer();
  await container.read(demoBootstrapProvider).ensureDemoReady();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyMasyaApp(),
    ),
  );
}
