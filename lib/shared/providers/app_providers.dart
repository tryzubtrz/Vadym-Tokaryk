import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/character_model.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/enums.dart';
import '../../data/models/food_item.dart';
import '../../data/models/friend_model.dart';
import '../../data/models/growth_state.dart';
import '../../data/models/user_model.dart';
import '../../domain/services/auth_service.dart';
import '../../domain/services/character_service.dart';
import '../../domain/services/chat_service.dart';
import '../../domain/services/friends_service.dart';
import '../../domain/services/growth_service.dart';

/// Bootstrapping flag.
final appReadyProvider = StateProvider<bool>((ref) => false);

final downloadProgressProvider = StateProvider<double>((ref) => 0);
final downloadLabelProvider = StateProvider<String?>((ref) => null);

final userProvider =
    StateNotifierProvider<UserNotifier, UserModel?>((ref) => UserNotifier(ref));

class UserNotifier extends StateNotifier<UserModel?> {
  UserNotifier(this.ref) : super(ref.read(authServiceProvider).currentUser());
  final Ref ref;

  void refresh() => state = ref.read(authServiceProvider).currentUser();

  Future<void> setRealAge(int age) async {
    await ref.read(authServiceProvider).updateRealAge(age);
    refresh();
  }
}

final characterProvider =
    StateNotifierProvider<CharacterNotifier, CharacterModel?>((ref) {
  return CharacterNotifier(ref);
});

class CharacterNotifier extends StateNotifier<CharacterModel?> {
  CharacterNotifier(this.ref)
      : super(ref.read(characterServiceProvider).load());

  final Ref ref;
  InteractionGesture? lastGesture;

  Future<void> refresh() async {
    state = await ref.read(characterServiceProvider).tick();
  }

  Future<void> create({
    required String name,
    required CharacterType type,
  }) async {
    state = await ref.read(characterServiceProvider).create(
          name: name,
          type: type,
        );
  }

  Future<void> feed(FoodItem food) async {
    state = await ref.read(characterServiceProvider).feed(food);
  }

  Future<void> buyFood(FoodItem item, int pack) async {
    state = await ref.read(characterServiceProvider).buyFoodPack(item, pack);
  }

  Future<void> wash(double amount) async {
    state = await ref.read(characterServiceProvider).wash(amount: amount);
  }

  Future<void> brushTeeth() async {
    state = await ref.read(characterServiceProvider).brushTeeth();
  }

  Future<void> comb() async {
    state = await ref.read(characterServiceProvider).combHair();
  }

  Future<void> toilet() async {
    state = await ref.read(characterServiceProvider).useToilet();
  }

  Future<void> sleep(bool lightsOff) async {
    state = await ref.read(characterServiceProvider).sleep(lightsOff: lightsOff);
  }

  Future<void> wake() async {
    state = await ref.read(characterServiceProvider).wakeUp();
  }

  Future<void> interact(InteractionGesture g) async {
    lastGesture = g;
    state = await ref.read(characterServiceProvider).applyInteraction(g);
  }
}

final fridgeProvider = Provider<List<FoodItem>>((ref) {
  ref.watch(characterProvider);
  return ref.watch(characterServiceProvider).loadFridge();
});

final growthDayProvider =
    StateNotifierProvider<GrowthDayNotifier, GrowthState>((ref) {
  return GrowthDayNotifier(ref);
});

class GrowthDayNotifier extends StateNotifier<GrowthState> {
  GrowthDayNotifier(this.ref)
      : super(ref.read(growthServiceProvider).loadDay());
  final Ref ref;

  Future<void> refresh() async {
    state = ref.read(growthServiceProvider).loadDay();
  }

  Future<String?> completeCare(CareSlot slot) async {
    final ev = await ref.read(growthServiceProvider).completeCare(slot);
    await ref.read(characterProvider.notifier).refresh();
    await refresh();
    return ev.message ??
        (ev.xpGained > 0 ? '+${ev.xpGained} XP, +${ev.coinsGained} коїнів' : null);
  }

  Future<String?> answerQuestion(String answer) async {
    final ev = await ref.read(growthServiceProvider).answerDailyQuestion(answer);
    await ref.read(characterProvider.notifier).refresh();
    await refresh();
    return ev.message ??
        (ev.xpGained > 0 ? '+${ev.xpGained} XP за відповідь!' : null);
  }

  Future<void> ensureQuestion() async {
    state = await ref.read(growthServiceProvider).ensureDailyQuestion();
  }
}

final chatHistoryProvider =
    StateNotifierProvider<ChatHistoryNotifier, List<ChatMessage>>((ref) {
  return ChatHistoryNotifier(ref);
});

class ChatHistoryNotifier extends StateNotifier<List<ChatMessage>> {
  ChatHistoryNotifier(this.ref)
      : super(ref.read(chatServiceProvider).loadHistory());
  final Ref ref;

  Future<void> send(String text, {bool voice = false}) async {
    await ref.read(chatServiceProvider).sendUserText(text, voice: voice);
    state = ref.read(chatServiceProvider).loadHistory();
    await ref.read(characterProvider.notifier).refresh();
  }

  Future<void> tip() async {
    final user = ref.read(userProvider);
    await ref.read(chatServiceProvider).lifeTip(
          userAge: user?.realAge ?? 12,
          countryCode: user?.countryCode ?? 'UA',
        );
    state = ref.read(chatServiceProvider).loadHistory();
  }
}

final friendsProvider =
    StateNotifierProvider<FriendsNotifier, List<FriendModel>>((ref) {
  return FriendsNotifier(ref);
});

class FriendsNotifier extends StateNotifier<List<FriendModel>> {
  FriendsNotifier(this.ref) : super(ref.read(friendsServiceProvider).load());
  final Ref ref;

  void refresh() => state = ref.read(friendsServiceProvider).load();

  Future<void> add({
    required String displayName,
    required String characterName,
    required int characterAge,
    required int realAge,
  }) async {
    await ref.read(friendsServiceProvider).addFriend(
          displayName: displayName,
          characterName: characterName,
          characterAge: characterAge,
          realAge: realAge,
        );
    refresh();
  }

  Future<List<FriendModel>> searchNearby() =>
      ref.read(friendsServiceProvider).searchNearby();
}

/// Bottom nav index for main shell.
final mainTabProvider = StateProvider<int>((ref) => 0);

/// Talking flag for mouth animation.
final characterTalkingProvider = StateProvider<bool>((ref) => false);
