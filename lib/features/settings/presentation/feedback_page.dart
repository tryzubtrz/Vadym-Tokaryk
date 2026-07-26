import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/services/news_service.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

class FeedbackPage extends ConsumerStatefulWidget {
  const FeedbackPage({super.key});

  @override
  ConsumerState<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends ConsumerState<FeedbackPage> {
  final _subject = TextEditingController();
  final _body = TextEditingController();

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(userProvider)?.email ?? '';

    return GradientScaffold(
      appBar: AppBar(title: const Text('Звʼязок з адміністрацією')),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _subject,
              decoration: const InputDecoration(labelText: 'Тема'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _body,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Повідомлення'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await ref.read(newsServiceProvider).sendFeedback(
                      subject: _subject.text.trim(),
                      body: _body.text.trim(),
                      email: email,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Надіслано. Дякуємо!')),
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('Надіслати'),
            ),
          ],
        ),
      ),
    );
  }
}
