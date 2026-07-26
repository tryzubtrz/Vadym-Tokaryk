import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/services/auth_service.dart';
import '../../domain/services/character_service.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/bathroom/presentation/bathroom_page.dart';
import '../../features/bedroom/presentation/bedroom_page.dart';
import '../../features/chat/presentation/chat_page.dart';
import '../../features/code/presentation/code_page.dart';
import '../../features/friends/presentation/friends_page.dart';
import '../../features/games/presentation/games_hub_page.dart';
import '../../features/home/presentation/home_shell.dart';
import '../../features/kitchen/presentation/kitchen_page.dart';
import '../../features/news/presentation/news_page.dart';
import '../../features/onboarding/presentation/age_page.dart';
import '../../features/onboarding/presentation/character_select_page.dart';
import '../../features/onboarding/presentation/language_page.dart';
import '../../features/onboarding/presentation/name_page.dart';
import '../../features/photo/presentation/photo_page.dart';
import '../../features/pet/presentation/pet_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/settings/presentation/feedback_page.dart';
import '../../features/settings/presentation/models_page.dart';
import '../../features/settings/presentation/storage_page.dart';
import '../../features/economy/presentation/economy_page.dart';

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    // Demo preview opens straight into the game.
    initialLocation: '/home',
    redirect: (context, state) {
      final auth = ref.read(authServiceProvider);
      final character = ref.read(characterServiceProvider).load();
      final loc = state.matchedLocation;
      final onboardingRoutes = {
        '/',
        '/language',
        '/login',
        '/register',
        '/age',
        '/character',
        '/name',
      };

      // If demo/character already ready — never force registration.
      if (auth.onboardingComplete && character != null) {
        if (onboardingRoutes.contains(loc)) return '/home';
        return null;
      }

      if (onboardingRoutes.contains(loc)) return null;
      if (!auth.isLoggedIn) return '/language';
      final user = auth.currentUser();
      if (user == null) return '/language';
      if (user.realAge < 12) return '/age';
      if (character == null) {
        if (loc == '/character' || loc == '/name') return null;
        return '/character';
      }
      return '/home';
    },
    routes: [
      GoRoute(path: '/', redirect: (_, __) => '/home'),
      GoRoute(path: '/language', builder: (_, __) => const LanguagePage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
      GoRoute(path: '/age', builder: (_, __) => const AgePage()),
      GoRoute(
        path: '/character',
        builder: (_, __) => const CharacterSelectPage(),
      ),
      GoRoute(path: '/name', builder: (_, __) => const NamePage()),
      GoRoute(path: '/home', builder: (_, __) => const HomeShell()),
      GoRoute(path: '/kitchen', builder: (_, __) => const KitchenPage()),
      GoRoute(path: '/bathroom', builder: (_, __) => const BathroomPage()),
      GoRoute(path: '/bedroom', builder: (_, __) => const BedroomPage()),
      GoRoute(path: '/games', builder: (_, __) => const GamesHubPage()),
      GoRoute(path: '/chat', builder: (_, __) => const ChatPage()),
      GoRoute(path: '/friends', builder: (_, __) => const FriendsPage()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
      GoRoute(path: '/news', builder: (_, __) => const NewsPage()),
      GoRoute(path: '/photo', builder: (_, __) => const PhotoPage()),
      GoRoute(path: '/code', builder: (_, __) => const CodePage()),
      GoRoute(path: '/pet', builder: (_, __) => const PetPage()),
      GoRoute(path: '/models', builder: (_, __) => const ModelsPage()),
      GoRoute(path: '/storage', builder: (_, __) => const StoragePage()),
      GoRoute(path: '/feedback', builder: (_, __) => const FeedbackPage()),
      GoRoute(path: '/economy', builder: (_, __) => const EconomyPage()),
    ],
  );
});
