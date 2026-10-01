import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/errors.dart';
import '../../core/result.dart';
import '../../core/utils/validators.dart';

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.subtitle, required this.child});
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [snagTeal, Color(0xFF14B8A6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: const Icon(
                        Icons.bookmark_added_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Snag',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 32),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({required this.controller, this.onSubmitted});
  final TextEditingController controller;
  final VoidCallback? onSubmitted;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    obscureText: _obscure,
    autofillHints: const [AutofillHints.password],
    textInputAction: TextInputAction.done,
    onFieldSubmitted: (_) => widget.onSubmitted?.call(),
    validator: validatePassword,
    decoration: InputDecoration(
      labelText: 'Password',
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        tooltip: _obscure ? 'Show password' : 'Hide password',
        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    ),
  );
}

String _withFrom(String path, String? from) =>
    from == null ? path : '$path?from=${Uri.encodeComponent(from)}';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.from});
  final String? from;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await ref
        .read(authRepositoryProvider)
        .signIn(login: _email.text, password: _password.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = res is Err<void> ? res.message : null;
    });
    // On success the router redirect takes over.
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      subtitle: 'Snag it now, find it later.',
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) _ErrorBox(_error!),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [
                  AutofillHints.email,
                  AutofillHints.username,
                ],
                textInputAction: TextInputAction.next,
                validator: validateLoginId,
                decoration: const InputDecoration(
                  labelText: 'Email or username',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              _PasswordField(controller: _password, onSubmitted: _submit),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('Sign in'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => context.go(_withFrom('/signup', widget.from)),
                child: const Text("New here? Create an account"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key, this.from});
  final String? from;

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

enum _Availability { unknown, checking, available, taken, error }

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _info;
  _Availability _availability = _Availability.unknown;
  Timer? _debounce;
  int _checkSeq = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String raw) {
    final lower = raw.toLowerCase();
    if (lower != raw) {
      _username.value = _username.value.copyWith(
        text: lower,
        selection: TextSelection.collapsed(offset: lower.length),
      );
    }
    _debounce?.cancel();
    if (validateUsername(lower) != null) {
      setState(() => _availability = _Availability.unknown);
      return;
    }
    setState(() => _availability = _Availability.checking);
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final seq = ++_checkSeq;
      final res = await ref
          .read(authRepositoryProvider)
          .isUsernameAvailable(lower);
      if (!mounted || seq != _checkSeq) return;
      setState(() {
        _availability = switch (res) {
          Ok(value: true) => _Availability.available,
          Ok() => _Availability.taken,
          Err() => _Availability.error,
        };
      });
    });
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (_availability == _Availability.taken) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final res = await ref
        .read(authRepositoryProvider)
        .signUp(
          email: _email.text,
          password: _password.text,
          username: _username.text.trim().toLowerCase(),
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (res) {
        case Ok(value: true):
          break; // Signed in; router redirect navigates.
        case Ok():
          _info =
              'Account created. Check your inbox to confirm your email, '
              'then sign in.';
        case Err(:final message):
          _error = message;
          if (message.contains('username')) {
            _availability = _Availability.taken;
          }
      }
    });
  }

  Widget? _usernameSuffix(ColorScheme scheme) => switch (_availability) {
    _Availability.checking => const Padding(
      padding: EdgeInsets.all(14),
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
    _Availability.available => Icon(Icons.check_circle, color: scheme.primary),
    _Availability.taken => Icon(Icons.cancel, color: scheme.error),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _AuthScaffold(
      subtitle: 'Create your private inbox.',
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) _ErrorBox(_error!),
              if (_info != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _info!,
                    style: TextStyle(color: scheme.onPrimaryContainer),
                  ),
                ),
              TextFormField(
                controller: _username,
                autocorrect: false,
                maxLength: 20,
                autofillHints: const [AutofillHints.newUsername],
                textInputAction: TextInputAction.next,
                onChanged: _onUsernameChanged,
                validator: (v) {
                  final err = validateUsername(v);
                  if (err != null) return err;
                  if (_availability == _Availability.taken) {
                    return 'That username is already taken';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Username',
                  prefixIcon: const Icon(Icons.alternate_email),
                  suffixIcon: _usernameSuffix(scheme),
                  helperText: switch (_availability) {
                    _Availability.available => 'Available',
                    _Availability.error => Messages.serverUnreachable,
                    _ => 'a–z, 0–9 and _, 3–20 characters',
                  },
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                validator: validateEmail,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
              ),
              const SizedBox(height: 12),
              _PasswordField(controller: _password, onSubmitted: _submit),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy || _availability == _Availability.taken
                    ? null
                    : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('Create account'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => context.go(_withFrom('/login', widget.from)),
                child: const Text('Already have an account? Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
