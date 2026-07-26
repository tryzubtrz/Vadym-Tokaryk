import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/food_item.dart';
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
      pose: CharacterPose.eat,
      topBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            const TomBackButton(),
            const SizedBox(width: 8),
            LevelBadge(level: character.age, progress: character.yearProgress),
            const Spacer(),
            TomCurrencyBar(coins: character.coins, gems: character.donateCoins),
          ],
        ),
      ),
      overlay: Stack(
        children: [
          // Drop food onto the 3D scene character area
          Positioned.fill(
            child: DragTarget<FoodItem>(
              onAcceptWithDetails: (details) async {
                setState(() => _reaction = null);
                try {
                  await ref.read(characterProvider.notifier).feed(details.data);
                  setState(() => _reaction = 'Ням-ням! 😋');
                } catch (e) {
                  setState(() => _reaction = '$e');
                }
              },
              builder: (context, candidate, _) => const SizedBox.expand(),
            ),
          ),
          if (_reaction != null)
            Positioned(
              top: 110,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  _reaction!,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 10, color: Colors.black54)],
                  ),
                ).animate().scale().fadeOut(delay: 1100.ms),
              ),
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
                icon: Icons.kitchen,
                color: AppColors.brandSky,
                selected: _fridgeOpen,
                onTap: () => setState(() => _fridgeOpen = !_fridgeOpen),
              ),
              const SizedBox(width: 16),
              TomActionButton(
                icon: Icons.storefront,
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
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: fridge.isEmpty
                        ? const Center(child: Text('Порожньо — купи їжу'))
                        : ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.all(10),
                            children: [
                              for (final food in fridge) _DraggableFood(food: food),
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
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.65,
              builder: (_, controller) {
                return ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      '🛒 Магазин їжі',
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
                                        content: Text(
                                          'Куплено ${item.nameUk} ×$pack',
                                        ),
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
                );
              },
            );
          },
        );
      },
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

  Widget _chip() {
    return Container(
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
          Text(food.nameUk,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          Text('×${food.quantity}', style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
