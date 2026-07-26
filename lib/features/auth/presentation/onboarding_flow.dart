import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../character/domain/enums.dart';
import '../../character/providers/app_providers.dart';

const kLanguages = <(String, String)>[
  ('uk', 'Українська'),
  ('en', 'English'),
  ('pl', 'Polski'),
  ('de', 'Deutsch'),
  ('fr', 'Français'),
  ('es', 'Español'),
  ('it', 'Italiano'),
  ('pt', 'Português'),
  ('cs', 'Čeština'),
  ('sk', 'Slovenčina'),
  ('ro', 'Română'),
  ('hu', 'Magyar'),
  ('tr', 'Türkçe'),
  ('ar', 'العربية'),
  ('ja', '日本語'),
  ('ko', '한국어'),
  ('zh', '中文'),
  ('hi', 'हिन्दी'),
  ('nl', 'Nederlands'),
  ('sv', 'Svenska'),
  ('no', 'Norsk'),
];

class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  int _step = 0;
  String _lang = 'uk';
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _age = TextEditingController();
  final _name = TextEditingController();
  CharacterType? _type;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _age.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    setState(() => _error = null);
    if (_step == 0) {
      await ref.read(sessionProvider.notifier).setLanguage(_lang);
      if (!mounted) return;
      setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      if (!_email.text.contains('@') || _pass.text.length < 4) {
        setState(() => _error = 'Вкажи email і пароль (мін. 4 символи)');
        return;
      }
      await ref.read(sessionProvider.notifier).setEmail(_email.text);
      if (!mounted) return;
      setState(() => _step = 2);
      return;
    }
    if (_step == 2) {
      final age = int.tryParse(_age.text.trim());
      if (age == null || age < AppConstants.minUserAge) {
        setState(
          () => _error = 'Вік користувача від ${AppConstants.minUserAge}+',
        );
        return;
      }
      await ref.read(sessionProvider.notifier).setRealAge(age);
      if (!mounted) return;
      setState(() => _step = 3);
      return;
    }
    if (_step == 3) {
      if (_type == null) {
        setState(() => _error = 'Обери персонажа');
        return;
      }
      setState(() => _step = 4);
      return;
    }
    if (_step == 4) {
      if (_name.text.trim().length < 2) {
        setState(() => _error = 'Введи імʼя (мін. 2 літери)');
        return;
      }
      await ref.read(characterProvider.notifier).create(
            name: _name.text,
            type: _type!,
          );
      await ref.read(sessionProvider.notifier).completeOnboarding();
      if (mounted) context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(
                value: (_step + 1) / 5,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
                color: AppColors.coral,
                backgroundColor: Colors.black12,
              ),
              const SizedBox(height: 18),
              Text(
                switch (_step) {
                  0 => 'Обери мову',
                  1 => 'Реєстрація',
                  2 => 'Твій вік',
                  3 => 'Обери друга',
                  _ => 'Імʼя персонажа',
                },
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 12),
              Expanded(child: _body()),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.coral,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ElevatedButton(
                onPressed: _next,
                child: Text(_step == 4 ? 'Почати!' : 'Далі'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    return switch (_step) {
      0 => ListView(
          children: [
            for (final lang in kLanguages)
              ListTile(
                title: Text(lang.$2),
                trailing: _lang == lang.$1
                    ? const Icon(Icons.check_circle, color: AppColors.mint)
                    : null,
                onTap: () => setState(() => _lang = lang.$1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                tileColor: _lang == lang.$1
                    ? AppColors.peach.withValues(alpha: 0.35)
                    : null,
              ),
          ],
        ),
      1 => ListView(
          children: [
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'Пароль'),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.apple),
              label: const Text('Продовжити з Apple (скоро)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.g_mobiledata, size: 32),
              label: const Text('Продовжити з Google (скоро)'),
            ),
          ],
        ),
      2 => ListView(
          children: [
            const Text(
              'Скільки тобі років? (персонажу буде 4; це вік гравця)',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _age,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Наприклад 14'),
            ),
          ],
        ),
      3 => Row(
          children: [
            Expanded(child: _heroCard(CharacterType.syryk, AppColors.sky)),
            const SizedBox(width: 12),
            Expanded(child: _heroCard(CharacterType.masya, AppColors.peach)),
          ],
        ),
      _ => ListView(
          children: [
            Text(
              'Як звати ${_type?.labelUk ?? 'друга'}?',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Імʼя'),
            ),
          ],
        ),
    };
  }

  Widget _heroCard(CharacterType type, Color color) {
    final selected = _type == type;
    return GestureDetector(
      onTap: () => setState(() => _type = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.55 : 0.25),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppColors.coral : Colors.transparent,
            width: 3,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor: Colors.white,
              child: Text(
                type == CharacterType.masya ? '🐱' : '😺',
                style: const TextStyle(fontSize: 40),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              type.labelUk,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
            Text(type.subtitleUk),
          ],
        ),
      ),
    );
  }
}
