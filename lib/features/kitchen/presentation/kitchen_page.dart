import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../character/domain/character_model.dart';
import '../../character/providers/app_providers.dart';
import '../../character/widgets/living_character.dart';
import '../../growth/domain/care_helper.dart';

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
    final msg = await ref.read(characterProvider.notifier).feed(food);
    await awardCareIfNeeded(ref);
    if (!mounted) return;
    setState(() => _reaction = msg);
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(characterProvider);
    final fridge = ref.watch(fridgeProvider);
    if (c == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/rooms/bg_kitchen_empty.png',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                Container(decoration: const BoxDecoration(gradient: AppColors.kitchen)),
          ),
          Align(
            alignment: const Alignment(0, -0.05),
            child: DragTarget<FoodItem>(
              onAcceptWithDetails: (d) => _feed(d.data),
              builder: (context, candidate, _) {
                return LivingCharacter(
                  character: c,
                  size: MediaQuery.sizeOf(context).width * 0.66,
                  pose: _pose,
                );
              },
            ),
          ),
          if (_reaction != null)
            Positioned(
              top: 120,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  _reaction!,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                  ),
                ).animate().scale().fadeOut(delay: 1000.ms),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _back(context),
                  const SizedBox(width: 8),
                  Text(
                    'Кухня · ${c.bodyWeight.name}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black45)],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '🪙 ${c.regularCoins}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _circleBtn(
                        Icons.kitchen,
                        AppColors.sky,
                        () => setState(() => _fridgeOpen = !_fridgeOpen),
                        selected: _fridgeOpen,
                      ),
                      const SizedBox(width: 16),
                      _circleBtn(
                        Icons.storefront,
                        AppColors.coral,
                        () => _openShop(context),
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
                                      for (final f in fridge) _DraggableFood(food: f),
                                    ],
                                  ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _back(BuildContext context) => GestureDetector(
        onTap: () => Navigator.maybePop(context),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
      );

  Widget _circleBtn(
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool selected = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: selected ? 60 : 54,
        height: selected ? 60 : 54,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: Icon(icon, color: Colors.white),
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
