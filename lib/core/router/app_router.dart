import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_stub_page.dart';
import '../../features/home/presentation/splash_page.dart';
import '../utils/stub_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeStubPage(),
    ),
    GoRoute(
      path: '/auth',
      builder: (context, state) => const StubPage(title: 'Автентифікація'),
    ),
    GoRoute(
      path: '/character',
      builder: (context, state) => const StubPage(title: 'Персонаж'),
    ),
    GoRoute(
      path: '/kitchen',
      builder: (context, state) => const StubPage(title: 'Кухня'),
    ),
    GoRoute(
      path: '/bathroom',
      builder: (context, state) => const StubPage(title: 'Ванна'),
    ),
    GoRoute(
      path: '/bedroom',
      builder: (context, state) => const StubPage(title: 'Спальня'),
    ),
    GoRoute(
      path: '/games',
      builder: (context, state) => const StubPage(title: 'Ігри'),
    ),
    GoRoute(
      path: '/chat',
      builder: (context, state) => const StubPage(title: 'Чат'),
    ),
    GoRoute(
      path: '/photo',
      builder: (context, state) => const StubPage(title: 'Фото'),
    ),
    GoRoute(
      path: '/code',
      builder: (context, state) => const StubPage(title: 'Кімната коду'),
    ),
    GoRoute(
      path: '/friends',
      builder: (context, state) => const StubPage(title: 'Друзі'),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const StubPage(title: 'Налаштування'),
    ),
    GoRoute(
      path: '/growth',
      builder: (context, state) => const StubPage(title: 'Ріст'),
    ),
    GoRoute(
      path: '/economy',
      builder: (context, state) => const StubPage(title: 'Економіка'),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Text('Маршрут не знайдено: ${state.uri}')),
  ),
);
