import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_store.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key, this.initialMode = AuthMode.signIn});

  final AuthMode initialMode;

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

enum AuthMode { signIn, signUp }

class _AuthPageState extends ConsumerState<AuthPage> {
  late AuthMode _mode;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _isSignUp => _mode == AuthMode.signUp;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                elevation: 0,
                color: scheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(Icons.track_changes_rounded,
                            size: 42, color: scheme.primary),
                        const SizedBox(height: 16),
                        Text('FocusFlow AI',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(
                            _isSignUp
                                ? 'Create a calm workspace for meaningful progress.'
                                : 'Return to the next meaningful step.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: 24),
                        SegmentedButton<AuthMode>(
                          segments: const [
                            ButtonSegment(
                                value: AuthMode.signIn,
                                label: Text('Log in'),
                                icon: Icon(Icons.login)),
                            ButtonSegment(
                                value: AuthMode.signUp,
                                label: Text('Sign up'),
                                icon: Icon(Icons.person_add_alt_1)),
                          ],
                          selected: {_mode},
                          onSelectionChanged: _busy
                              ? null
                              : (selection) => setState(() {
                                    _mode = selection.first;
                                    _error = null;
                                  }),
                        ),
                        const SizedBox(height: 24),
                        if (_isSignUp) ...[
                          TextFormField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            decoration: const InputDecoration(
                                labelText: 'Your name',
                                prefixIcon: Icon(Icons.person_outline),
                                border: OutlineInputBorder()),
                            validator: (value) =>
                                value == null || value.trim().length < 2
                                    ? 'Enter your name'
                                    : null,
                          ),
                          const SizedBox(height: 14),
                        ],
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                              labelText: 'Email address',
                              prefixIcon: Icon(Icons.email_outlined),
                              border: OutlineInputBorder()),
                          validator: (value) => value == null ||
                                  !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                      .hasMatch(value.trim())
                              ? 'Enter a valid email'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                              labelText: 'Password',
                              helperText:
                                  _isSignUp ? 'At least 8 characters' : null,
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () => setState(() =>
                                      _obscurePassword = !_obscurePassword),
                                  icon: Icon(_obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined))),
                          validator: (value) =>
                              value == null || value.length < 8
                                  ? 'Use at least 8 characters'
                                  : null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Semantics(
                              liveRegion: true,
                              child: Text(_error!,
                                  style: TextStyle(color: scheme.error))),
                        ],
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _busy ? null : _submit,
                          icon: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : Icon(_isSignUp
                                  ? Icons.person_add_alt_1
                                  : Icons.login),
                          label: Text(_busy
                              ? 'Working…'
                              : _isSignUp
                                  ? 'Create local account'
                                  : 'Log in'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                            onPressed: _busy ? null : _continueOffline,
                            icon: const Icon(Icons.cloud_off_outlined),
                            label: const Text('Continue offline as guest')),
                        const SizedBox(height: 16),
                        Text(
                            'Your account and session stay on this device. FocusFlow does not send passwords or add telemetry by default.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall),
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
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final store = ref.read(authStoreProvider.notifier);
      if (_isSignUp) {
        await store.signUp(
            name: _nameController.text,
            email: _emailController.text,
            password: _passwordController.text);
      } else {
        await store.signIn(
            email: _emailController.text, password: _passwordController.text);
      }
      if (mounted) context.go('/');
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continueOffline() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    await ref.read(authStoreProvider.notifier).continueOffline();
    if (mounted) {
      setState(() => _busy = false);
      context.go('/');
    }
  }
}
