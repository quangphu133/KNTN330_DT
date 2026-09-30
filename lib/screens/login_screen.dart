import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: const Text('HUIT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 20),
                        Text('Đăng nhập', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 8),
                        const Text('Ứng dụng dành cho nhân viên', textAlign: TextAlign.center),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.username, AutofillHints.email],
                          decoration: const InputDecoration(labelText: 'Địa chỉ email', prefixIcon: Icon(Icons.email_outlined)),
                          validator: (value) => value == null || !value.contains('@') ? 'Nhập địa chỉ email hợp lệ' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          decoration: const InputDecoration(labelText: 'Mật khẩu', prefixIcon: Icon(Icons.lock_outline)),
                          validator: (value) => value == null || value.isEmpty ? 'Nhập mật khẩu' : null,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        if (auth.errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Text(auth.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        ],
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          onPressed: auth.isLoading ? null : _submit,
                          icon: auth.isLoading
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.login_rounded),
                          label: const Text('Đăng nhập'),
                        ),
                        const SizedBox(height: 14),
                        const Text('Tài khoản do quản trị viên cấp.', textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    try {
      await ref.read(authProvider.notifier).login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } catch (_) {}
  }
}
