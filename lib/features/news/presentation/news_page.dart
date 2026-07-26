import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/services/news_service.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

class NewsPage extends ConsumerWidget {
  const NewsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final news = ref.watch(newsServiceProvider).load();
    final fmt = DateFormat('dd.MM.yyyy HH:mm');

    return GradientScaffold(
      appBar: AppBar(title: const Text('Новини від розробника')),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: news.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final n = news[i];
          return Material(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              title: Text(
                n.title,
                style: TextStyle(
                  fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w800,
                ),
              ),
              subtitle: Text('${n.body}\n${fmt.format(n.publishedAt)}'),
              isThreeLine: true,
              onTap: () async {
                await ref.read(newsServiceProvider).markRead(n.id);
                // ignore: unused_result
                ref.refresh(newsServiceProvider);
              },
            ),
          );
        },
      ),
    );
  }
}
