import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/services/auth_service.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _afterAuth() async {
    ref.read(userProvider.notifier).refresh();
    final character = ref.read(characterProvider);
    if (!mounted) return;
    if (character == null) {
      context.go('/age');
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text(
              'MyMasyaAI',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppColors.brandCoral,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Увійти',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Пароль',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading
                  ? null
                  : () async {
                      setState(() {
                        _loading = true;
                        _error = null;
                      });
                      final res = await ref.read(authServiceProvider).loginWithEmail(
                            email: _email.text,
                            password: _password.text,
                          );
                      setState(() => _loading = false);
                      if (!res.success) {
                        setState(() => _error = res.error);
                        return;
                      }
                      await _afterAuth();
                    },
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Увійти'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loading
                  ? null
                  : () async {
                      setState(() => _loading = true);
                      final res =
                          await ref.read(authServiceProvider).loginWithApple();
                      setState(() => _loading = false);
                      if (res.success) await _afterAuth();
                    },
              icon: const Icon(Icons.apple),
              label: const Text('Увійти через Apple'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loading
                  ? null
                  : () async {
                      setState(() => _loading = true);
                      final res =
                          await ref.read(authServiceProvider).loginWithGoogle();
                      setState(() => _loading = false);
                      if (res.success) await _afterAuth();
                    },
              icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
              label: const Text('Увійти через Google'),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => context.go('/register'),
              child: const Text('Немає акаунта? Зареєструватися'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/home'),
              child: const Text('▶ Спробувати без реєстрації'),
            ),
          ],
        ),
      ),
    );
  }
}
