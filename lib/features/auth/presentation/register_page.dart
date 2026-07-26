import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/services/auth_service.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _awaitingCode = false;
  bool _loading = false;
  String? _error;
  String? _devHint;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
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
              'Реєстрація',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _awaitingCode
                  ? 'Введи код підтвердження з email'
                  : 'Email + пароль з підтвердженням коду',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            if (!_awaitingCode) ...[
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Пароль'),
              ),
            ] else ...[
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Код підтвердження',
                  counterText: '',
                ),
              ),
              if (_devHint != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Dev-код: $_devHint',
                    style: const TextStyle(color: AppColors.brandSky),
                  ),
                ),
            ],
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
                      final auth = ref.read(authServiceProvider);
                      if (!_awaitingCode) {
                        final res = await auth.registerWithEmail(
                          email: _email.text,
                          password: _password.text,
                        );
                        setState(() {
                          _loading = false;
                          if (res.success && res.needsEmailCode) {
                            _awaitingCode = true;
                            _devHint = auth.peekDevCode();
                          } else {
                            _error = res.error;
                          }
                        });
                      } else {
                        final res =
                            await auth.confirmEmailCode(_code.text.trim());
                        setState(() => _loading = false);
                        if (!res.success) {
                          setState(() => _error = res.error);
                          return;
                        }
                        ref.read(userProvider.notifier).refresh();
                        if (context.mounted) context.go('/age');
                      }
                    },
              child: Text(_awaitingCode ? 'Підтвердити' : 'Отримати код'),
            ),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Уже є акаунт'),
            ),
          ],
        ),
      ),
    );
  }
}
