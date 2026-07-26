import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/food_item.dart';
import '../../../features/character/animation/character_animator.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/currency_badge.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

class KitchenPage extends ConsumerStatefulWidget {
  const KitchenPage({super.key});

  @override
  ConsumerState<KitchenPage> createState() => _KitchenPageState();
}

class _KitchenPageState extends ConsumerState<KitchenPage> {
  bool _fridgeOpen = false;
  FoodItem? _flyingFood;
  String? _reaction;

  @override
  Widget build(BuildContext context) {
    final character = ref.watch(characterProvider);
    final fridge = ref.watch(fridgeProvider);
    if (character == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return GradientScaffold(
      gradient: AppColors.kitchenGradient,
      appBar: AppBar(
        title: const Text('Кухня'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CurrencyBadge(
              coins: character.coins,
              donateCoins: character.donateCoins,
            ),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Голод: ${character.needs.hunger.toStringAsFixed(0)}% · '
            'Тіло: ${character.bodyShape.name}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (_reaction != null)
            Text(
              _reaction!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.brandCoral,
              ),
            ).animate().scale().fadeOut(delay: 1200.ms),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                DragTarget<FoodItem>(
                  onAcceptWithDetails: (details) async {
                    setState(() {
                      _flyingFood = details.data;
                      _reaction = null;
                    });
                    try {
                      await ref
                          .read(characterProvider.notifier)
                          .feed(details.data);
                      setState(() {
                        _reaction = details.data.isFavorite
                            ? 'Ммм, улюблене! 😋'
                            : 'Ням-ням! 😋';
                        _flyingFood = null;
                      });
                    } catch (e) {
                      setState(() {
                        _reaction = e.toString();
                        _flyingFood = null;
                      });
                    }
                  },
                  builder: (context, candidate, _) {
                    return CharacterAnimator(
                      character: character,
                      size: 240,
                      talking: candidate.isNotEmpty,
                    );
                  },
                ),
                if (_flyingFood != null)
                  Positioned(
                    top: 40,
                    child: Text(
                      _flyingFood!.emoji,
                      style: const TextStyle(fontSize: 48),
                    ).animate().moveY(end: 80, duration: 400.ms).fadeOut(),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => setState(() => _fridgeOpen = !_fridgeOpen),
                icon: Icon(
                  _fridgeOpen
                      ? Icons.kitchen
                      : Icons.kitchen_outlined,
                ),
                label: Text(_fridgeOpen ? 'Закрити холодильник' : 'Відкрити холодильник'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _openShop(context),
                child: const Text('Магазин'),
              ),
            ],
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            height: _fridgeOpen ? 180 : 0,
            curve: Curves.easeOut,
            child: _fridgeOpen
                ? Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F6FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.brandSky),
                    ),
                    child: fridge.isEmpty
                        ? const Center(child: Text('Холодильник порожній'))
                        : ListView(
                            scrollDirection: Axis.horizontal,
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
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.7,
              builder: (_, controller) {
                return ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Купівля пакетами 1 / 5 / 10 / 20',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    for (final item in FoodCatalog.shop) ...[
                      Text(
                        '${item.emoji} ${item.nameUk}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
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
        child: Text(food.emoji, style: const TextStyle(fontSize: 48)),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _FoodChip(food: food),
      ),
      child: _FoodChip(food: food),
    );
  }
}

class _FoodChip extends StatelessWidget {
  const _FoodChip({required this.food});

  final FoodItem food;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      margin: const EdgeInsets.all(6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
}
