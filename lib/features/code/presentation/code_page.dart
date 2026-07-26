import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/services/code_service.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

class CodePage extends ConsumerStatefulWidget {
  const CodePage({super.key});

  @override
  ConsumerState<CodePage> createState() => _CodePageState();
}

class _CodePageState extends ConsumerState<CodePage> {
  final _title = TextEditingController(text: 'main.dart');
  final _code = TextEditingController();
  final _prompt = TextEditingController();
  String _language = 'dart';
  String? _output;

  @override
  void dispose() {
    _title.dispose();
    _code.dispose();
    _prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final character = ref.watch(characterProvider);
    final files = ref.watch(codeServiceProvider).loadFiles();
    if (character == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!character.codeRoomUnlocked) {
      return GradientScaffold(
        appBar: AppBar(title: const Text('Кімната коду')),
        child: const Center(
          child: Text('Відкривається з 20 років персонажа'),
        ),
      );
    }

    final code = ref.read(codeServiceProvider);

    return GradientScaffold(
      appBar: AppBar(title: const Text('Кімната коду')),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Назва файлу'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _language,
            items: const [
              DropdownMenuItem(value: 'dart', child: Text('Dart')),
              DropdownMenuItem(value: 'python', child: Text('Python')),
              DropdownMenuItem(value: 'js', child: Text('JavaScript')),
              DropdownMenuItem(value: 'kotlin', child: Text('Kotlin')),
            ],
            onChanged: (v) => setState(() => _language = v ?? 'dart'),
            decoration: const InputDecoration(labelText: 'Мова'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _code,
            maxLines: 12,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Код',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton(
                onPressed: () async {
                  await code.saveFile(
                    title: _title.text,
                    language: _language,
                    content: _code.text,
                  );
                  setState(() {});
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Збережено')),
                    );
                  }
                },
                child: const Text('Зберегти'),
              ),
              OutlinedButton(
                onPressed: () => setState(() => _output = code.explain(_code.text)),
                child: const Text('Пояснити'),
              ),
              OutlinedButton(
                onPressed: () {
                  final fixed = code.fix(_code.text);
                  setState(() {
                    _code.text = fixed;
                    _output = 'Код оновлено з підказками';
                  });
                },
                child: const Text('Виправити'),
              ),
              OutlinedButton(
                onPressed: () async {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['dart', 'py', 'js', 'kt', 'txt'],
                    withData: true,
                  );
                  if (result == null || result.files.isEmpty) return;
                  final f = result.files.first;
                  setState(() {
                    _title.text = f.name;
                    _code.text = f.bytes != null
                        ? String.fromCharCodes(f.bytes!)
                        : '';
                  });
                },
                child: const Text('Завантажити файл'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _prompt,
            decoration: const InputDecoration(
              labelText: 'Написати код за описом',
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _code.text = code.writeFromPrompt(_prompt.text);
              });
            },
            child: const Text('Згенерувати з промпту'),
          ),
          if (_output != null) ...[
            const SizedBox(height: 12),
            Text(_output!),
          ],
          const Divider(height: 32),
          Text('Файли', style: Theme.of(context).textTheme.titleMedium),
          for (final f in files)
            ListTile(
              title: Text(f.title),
              subtitle: Text('${f.language} · ${f.updatedAt}'),
              onTap: () {
                setState(() {
                  _title.text = f.title;
                  _language = f.language;
                  _code.text = f.content;
                });
              },
            ),
        ],
      ),
    );
  }
}
