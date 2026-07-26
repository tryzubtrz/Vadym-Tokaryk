import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/hive_boxes.dart';
import '../../data/models/news_item.dart';

class NewsService {
  NewsService();

  final _uuid = const Uuid();

  List<NewsItem> load() {
    final raw = HiveBoxes.news.get('items');
    if (raw is! List || raw.isEmpty) {
      final seeded = _seed();
      HiveBoxes.news.put('items', seeded.map((e) => e.toJson()).toList());
      return seeded;
    }
    return raw
        .whereType<Map>()
        .map((e) => NewsItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> markRead(String id) async {
    final list = load();
    final updated = list
        .map((e) => e.id == id ? e.copyWith(isRead: true) : e)
        .toList();
    await HiveBoxes.news.put('items', updated.map((e) => e.toJson()).toList());
  }

  Future<void> sendFeedback({
    required String subject,
    required String body,
    required String email,
  }) async {
    final tickets = List<Map>.from(
      HiveBoxes.news.get('feedback', defaultValue: <Map>[]) as List,
    );
    tickets.add({
      'id': _uuid.v4(),
      'subject': subject,
      'body': body,
      'email': email,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await HiveBoxes.news.put('feedback', tickets);
  }

  List<NewsItem> _seed() => [
        NewsItem(
          id: _uuid.v4(),
          title: 'Вітаємо в MyMasyaAI!',
          body:
              'Доглядай за персонажем щоранку, вдень і ввечері — так він росте швидше. '
              'З 10 років відкриються фото і пітомець, з 20 — кімната коду.',
          publishedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        NewsItem(
          id: _uuid.v4(),
          title: 'Офлайн-догляд завжди з тобою',
          body:
              'Без інтернету працюють кухня, ванна, сон, базові ігри та просте спілкування. '
              'Для нових моделей інтелекту потрібен інтернет.',
          publishedAt: DateTime.now().subtract(const Duration(hours: 5)),
        ),
      ];
}

final newsServiceProvider = Provider<NewsService>((ref) => NewsService());
