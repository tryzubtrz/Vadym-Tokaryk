import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/food_item.dart';
import '../../../features/character/domain/character_animation_state.dart';
import '../../../features/character/providers/character_animation_provider.dart';
import '../../../features/home/widgets/care_room_hud.dart';
import '../../../features/home/widgets/tom_style_ui.dart';
import '../../../shared/providers/app_providers.dart';

class KitchenPage extends ConsumerStatefulWidget {
  const KitchenPage({super.key});

  @override
  ConsumerState<KitchenPage> createState() => _KitchenPageState();
}

class _KitchenPageState extends ConsumerState<KitchenPage> {
  bool _fridgeOpen = true;
  String? _reaction;
  CharacterPose _pose = CharacterPose.eat;

  Future<void> _feed(FoodItem food) async {
    setState(() {
      _pose = CharacterPose.eat;
      _reaction = null;
    });
    ref
        .read(characterAnimationProvider.notifier)
        .setPose(CharacterAnimPose.eat);
    try {
      await ref.read(characterProvider.notifier).feed(food);
      final careMsg =
          await ref.read(growthDayProvider.notifier).tryAutoCare();
      if (!mounted) return;
      setState(() => _reaction = careMsg ?? 'Ням-ням!');
    } catch (e) {
      if (!mounted) return;
      setState(() => _reaction = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final character = ref.watch(characterProvider);
    final fridge = ref.watch(fridgeProvider);
    if (character == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return TomRoomStage(
      kind: RoomSceneKind.kitchen,
      character: character,
      pose: _pose,
      characterAlignment: const Alignment(0, 0.08),
      characterSizeFactor: 0.66,
      topBar: CareRoomHud(
        age: character.age,
        progress: character.yearProgress,
        coins: character.coins,
        gems: character.donateCoins,
        needs: character.needs,
        focusNeed: NeedType.hunger,
      ),
      overlay: Stack(
        children: [
          Positioned.fill(
            child: DragTarget<FoodItem>(
              onAcceptWithDetails: (details) => _feed(details.data),
              builder: (context, candidate, rejected) => IgnorePointer(
                ignoring: candidate.isEmpty,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: candidate.isEmpty
                        ? Colors.transparent
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),
          ),
          if (_reaction != null)
            Positioned(
              top: 130,
              left: 16,
              right: 16,
              child: CareReactionBanner(text: _reaction!)
                  .animate()
                  .scale(duration: 220.ms)
                  .fadeOut(delay: 1100.ms),
            ),
        ],
      ),
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TomActionButton(
                icon: Icons.kitchen_rounded,
                color: AppColors.brandSky,
                selected: _fridgeOpen,
                onTap: () => setState(() => _fridgeOpen = !_fridgeOpen),
              ),
              const SizedBox(width: 16),
              TomActionButton(
                icon: Icons.storefront_rounded,
                color: AppColors.brandCoral,
                onTap: () => _openShop(context),
              ),
            ],
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: _fridgeOpen ? 150 : 0,
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: _fridgeOpen
                ? Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: fridge.isEmpty
                        ? const Center(child: Text('Порожньо — купи їжу'))
                        : ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.all(10),
                            children: [
                              for (final food in fridge)
                                _DraggableFood(food: food),
                            ],
                          ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  void _openShop(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.65,
            builder: (_, controller) => ListView(
              controller: controller,
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Магазин їжі',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                for (final item in FoodCatalog.shop) ...[
                  Text('${item.emoji} ${item.nameUk}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final pack in FoodCatalog.packSizes)
                        ActionChip(
                          label: Text(
                            '×$pack (${FoodCatalog.packPrice(item, pack)})',
                          ),
                          onPressed: () async {
                            try {
                              await ref
                                  .read(characterProvider.notifier)
                                  .buyFood(item, pack);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('Куплено ${item.nameUk} ×$pack'),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$e')),
                                );
                              }
                            }
                          },
                        ),
                    ],
                  ),
                  const Divider(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DraggableFood extends StatelessWidget {
  const _DraggableFood({required this.food});
  final FoodItem food;

  @override
  Widget build(BuildContext context) {
    return Draggable<FoodItem>(
      data: food,
      feedback: Material(
        color: Colors.transparent,
        child: Text(food.emoji, style: const TextStyle(fontSize: 52)),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _chip()),
      child: _chip(),
    );
  }

  Widget _chip() => Container(
        width: 86,
        margin: const EdgeInsets.all(6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8F0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(food.emoji, style: const TextStyle(fontSize: 32)),
            Text(
              food.nameUk,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            Text('×${food.quantity}', style: const TextStyle(fontSize: 11)),
          ],
        ),
      );
}
