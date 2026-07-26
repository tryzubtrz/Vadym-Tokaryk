import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../character/providers/app_providers.dart';

class CodePage extends ConsumerStatefulWidget {
  const CodePage({super.key});

  @override
  ConsumerState<CodePage> createState() => _CodePageState();
}

class _CodePageState extends ConsumerState<CodePage> {
  final _ctrl = TextEditingController(
    text: 'print("Hello, MyMasyaAI!");',
  );
  String _out = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(characterProvider);
    if (c == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!c.codeUnlocked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Код')),
        body: const Center(
          child: Text(
            'Кімната коду відкривається з 20 років',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Кімната коду')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Напиши / поясни / виправ код (локальний stub LLM).',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _ctrl,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontFamily: 'monospace'),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => setState(() {
                    _out =
                        'Пояснення: цей код виводить привітання в консоль. '
                        'Функція print — стандартний вивід.';
                  }),
                  child: const Text('Пояснити'),
                ),
                ElevatedButton(
                  onPressed: () => setState(() {
                    _out =
                        'Фікс: код виглядає коректно. Додай перевірку вводу.';
                  }),
                  child: const Text('Виправити'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mint,
                  ),
                  onPressed: () => setState(() {
                    _out = '▶ Hello, MyMasyaAI!';
                  }),
                  child: const Text('Запустити'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _out.isEmpty ? 'Вивід…' : _out,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
