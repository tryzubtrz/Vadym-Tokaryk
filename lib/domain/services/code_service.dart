import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/hive_boxes.dart';
import 'character_service.dart';

class CodeSnippet {
  const CodeSnippet({
    required this.id,
    required this.title,
    required this.language,
    required this.content,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String language;
  final String content;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'language': language,
        'content': content,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory CodeSnippet.fromJson(Map<String, dynamic> json) => CodeSnippet(
        id: json['id'] as String,
        title: json['title'] as String,
        language: json['language'] as String,
        content: json['content'] as String,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

class CodeService {
  CodeService(this._character);

  final CharacterService _character;
  final _uuid = const Uuid();

  void _ensureUnlocked() {
    final c = _character.load();
    if (c == null || !c.codeRoomUnlocked) {
      throw StateError('Кімната коду відкривається з 20 років');
    }
  }

  List<CodeSnippet> loadFiles() {
    final raw = HiveBoxes.inventory.get('code_files');
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => CodeSnippet.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> _save(List<CodeSnippet> list) async {
    await HiveBoxes.inventory
        .put('code_files', list.map((e) => e.toJson()).toList());
  }

  Future<CodeSnippet> saveFile({
    required String title,
    required String language,
    required String content,
    String? id,
  }) async {
    _ensureUnlocked();
    final list = loadFiles();
    final snippet = CodeSnippet(
      id: id ?? _uuid.v4(),
      title: title,
      language: language,
      content: content,
      updatedAt: DateTime.now(),
    );
    final idx = list.indexWhere((e) => e.id == snippet.id);
    if (idx >= 0) {
      list[idx] = snippet;
    } else {
      list.insert(0, snippet);
    }
    await _save(list);
    return snippet;
  }

  String explain(String code) {
    _ensureUnlocked();
    final lines = code.trim().split('\n').length;
    return 'Цей фрагмент містить близько $lines рядків. '
        'Я бачу структуру програми і можу допомогти спростити логіку, '
        'виправити помилки або додати тести. Уточни, що саме потрібно.';
  }

  String fix(String code) {
    _ensureUnlocked();
    if (code.contains('print(') && !code.contains(';') && code.contains('void')) {
      return '// Можливі правки:\n$code\n// Перевір дужки та ; у кінці виразів.';
    }
    return '// Оновлений варіант (локальна підказка):\n'
        '${code.trim()}\n'
        '// Порада: розбий довгі функції та додай обробку помилок.';
  }

  String writeFromPrompt(String prompt) {
    _ensureUnlocked();
    return '// Згенеровано за запитом: $prompt\n'
        'void main() {\n'
        "  print('Hello from MyMasyaAI');\n"
        '  // TODO: реалізувати логіку\n'
        '}\n';
  }
}

final codeServiceProvider = Provider<CodeService>(
  (ref) => CodeService(ref.watch(characterServiceProvider)),
);
