import 'package:flutter/material.dart';

import '../account.dart';
import '../store.dart';
import '../theme.dart';

/// Bejelentkezés és regisztráció. Az app csak fiókkal használható; az adatok a fiókhoz kötődnek.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _register = true;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;
  String? _info;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Akinek már van fiókja, annak a bejelentkezés legyen elöl.
    if (_name.text.isEmpty && StoreScope.of(context).myName.isNotEmpty) _name.text = StoreScope.of(context).myName;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final store = StoreScope.of(context);
    final email = _email.text.trim();
    final password = _password.text;
    String? problem;
    if (_register && _name.text.trim().isEmpty) problem = 'Add meg a neved.';
    if (!email.contains('@') || !email.contains('.')) problem ??= 'Add meg az e-mail-címed.';
    if (password.length < 6) problem ??= 'A jelszó legalább 6 karakter legyen.';
    if (problem != null) return setState(() => _error = problem);

    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      if (_register) {
        final name = _name.text.trim();
        await Account.instance.register(name: name, email: email, password: password);
        if (store.myName.isEmpty) store.setMyName(name);
        store.beginOnboarding(); // az első lépések csak az új regisztrációnál jönnek
      } else {
        await Account.instance.login(email: email, password: password);
      }
      // A továbbiakat (adatok betöltése) az AuthGate intézi.
    } on AccountException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Valami hiba történt. Van internet? ($e)');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    final store = StoreScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final user = await Account.instance.signInWithGoogle();
      if (Account.instance.lastSignInWasNew) store.beginOnboarding();
      if (store.myName.isEmpty && (user.displayName ?? '').isNotEmpty) store.setMyName(user.displayName!);
    } on AccountException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Valami hiba történt. Van internet? ($e)');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final email = _email.text.trim();
    if (!email.contains('@')) return setState(() => _error = 'Írd be az e-mail-címed, és oda küldöm a linket.');
    setState(() => _busy = true);
    try {
      await Account.instance.resetPassword(email);
      if (mounted) {
        setState(() {
          _error = null;
          _info = 'Elküldtem a jelszó-visszaállító linket ide: $email. Nézd meg a spam mappát is!';
        });
      }
    } on AccountException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final hasLocalData = store.tasks.isNotEmpty || store.habits.isNotEmpty || store.events.isNotEmpty;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.headerGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            padding: EdgeInsets.fromLTRB(24, MediaQuery.paddingOf(context).top + 40, 24, 32),
            child: Column(
              children: [
                Image.asset(
                  'assets/icon/icon_foreground.png',
                  width: 120,
                  height: 120,
                  errorBuilder: (_, _, _) => const Text('🌿', style: TextStyle(fontSize: 64)),
                ),
                Text('LIFEUP', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white)),
                const SizedBox(height: 6),
                const Text(
                  'Az életed. Az embereid. Az időd.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: _busy ? null : _google,
                    icon: const Text(
                      'G',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF4285F4)),
                    ),
                    label: const Text('Folytatás Google-fiókkal', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('vagy e-maillel', style: TextStyle(color: AppColors.textMuted)),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                  ),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: true, label: Text('Regisztráció')),
                      ButtonSegment(value: false, label: Text('Bejelentkezés')),
                    ],
                    selected: {_register},
                    onSelectionChanged: (s) => setState(() {
                      _register = s.first;
                      _error = null;
                      _info = null;
                    }),
                  ),
                  const SizedBox(height: 20),
                  if (_register) ...[
                    TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      maxLength: 40,
                      decoration: const InputDecoration(
                        labelText: 'Neved',
                        prefixIcon: Icon(Icons.person_outline),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'E-mail-cím', prefixIcon: Icon(Icons.mail_outline)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: !_showPassword,
                    autofillHints: [_register ? AutofillHints.newPassword : AutofillHints.password],
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: _register ? 'Jelszó (legalább 6 karakter)' : 'Jelszó',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: _showPassword ? 'Jelszó elrejtése' : 'Jelszó mutatása',
                        icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w700),
                    ),
                  ],
                  if (_info != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _info!,
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                        : Text(_register ? 'Fiók létrehozása' : 'Bejelentkezés'),
                  ),
                  if (!_register)
                    TextButton(onPressed: _busy ? null : _forgot, child: const Text('Elfelejtettem a jelszavam')),
                  if (hasLocalData) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _register
                              ? '💾 Az ezen az eszközön lévő naptárad, feladataid és céljaid az új fiókodba kerülnek.'
                              : '⚠️ Bejelentkezéskor a fiókod adatai kerülnek az ezen az eszközön lévők helyére. '
                                    'Ha ezeket is meg akarod tartani, inkább regisztrálj velük új fiókot.',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
