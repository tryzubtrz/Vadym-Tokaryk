import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/onboarding_flow.dart';
import '../../features/bathroom/presentation/bathroom_page.dart';
import '../../features/bedroom/presentation/bedroom_page.dart';
import '../../features/chat/presentation/chat_page.dart';
import '../../features/code_room/presentation/code_page.dart';
import '../../features/economy/presentation/economy_page.dart';
import '../../features/friends/presentation/friends_page.dart';
import '../../features/games/presentation/games_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/home/presentation/news_page.dart';
import '../../features/home/presentation/splash_page.dart';
import '../../features/kitchen/presentation/kitchen_page.dart';
import '../../features/photo/presentation/photo_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/character/providers/app_providers.dart';

final _rootKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionProvider);
  final character = ref.watch(characterProvider);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: _RouterRefresh(ref),
    redirect: (context, state) {
      final path = state.matchedLocation;
      if (path == '/splash') return null;
      final done = session.onboardingComplete && character != null;
      final onboarding = path == '/onboarding';
      if (!done && !onboarding) return '/onboarding';
      if (done && onboarding) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingFlow(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomePage()),
      GoRoute(path: '/kitchen', builder: (context, state) => const KitchenPage()),
      GoRoute(
        path: '/bathroom',
        builder: (context, state) => const BathroomPage(),
      ),
      GoRoute(path: '/bedroom', builder: (context, state) => const BedroomPage()),
      GoRoute(path: '/games', builder: (context, state) => const GamesPage()),
      GoRoute(path: '/chat', builder: (context, state) => const ChatPage()),
      GoRoute(path: '/photo', builder: (context, state) => const PhotoPage()),
      GoRoute(path: '/code', builder: (context, state) => const CodePage()),
      GoRoute(path: '/friends', builder: (context, state) => const FriendsPage()),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(path: '/economy', builder: (context, state) => const EconomyPage()),
      GoRoute(path: '/news', builder: (context, state) => const NewsPage()),
      GoRoute(
        path: '/growth',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Відкрий кільце віку на головному')),
        ),
      ),
      GoRoute(path: '/auth', redirect: (context, state) => '/onboarding'),
      GoRoute(path: '/character', redirect: (context, state) => '/home'),
    ],
  );
});

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this.ref) {
    ref.listen(sessionProvider, (previous, next) => notifyListeners());
    ref.listen(characterProvider, (previous, next) => notifyListeners());
  }
  final Ref ref;
}
