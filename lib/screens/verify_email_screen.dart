import 'dart:async';

import 'package:flutter/material.dart';

import '../account.dart';
import '../availability.dart' show AvailabilityStatus;
import '../theme.dart';

/// Regisztráció után: az e-mail-cím megerősítése. Küldtünk egy levelet; amint a benne lévő linkre koppint,
/// az app magától továbblép (pár másodpercenként és visszatéréskor is megnézi).
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, required this.email, required this.onVerified, this.pollEvery});

  final String email;
  final VoidCallback onVerified;

  /// Milyen gyakran nézze meg magától (tesztben rövidebb vagy kikapcsolt).
  final Duration? pollEvery;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> with WidgetsBindingObserver {
  Timer? _poll;
  Timer? _cooldownTimer;
  int _cooldown = 0;
  bool _busy = false;
  bool _done = false;
  String? _message;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poll = Timer.periodic(widget.pollEvery ?? const Duration(seconds: 4), (_) => _check(silent: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check(silent: true);
  }

  Future<void> _check({bool silent = false}) async {
    if (_done || (_busy && silent)) return;
    if (!silent) setState(() => _busy = true);
    try {
      final verified = await Account.instance.checkVerified();
      if (!mounted || _done) return;
      if (verified) {
        _done = true;
        _poll?.cancel();
        widget.onVerified();
        return;
      }
      if (!silent) {
        setState(() {
          _error = true;
          _message = 'Még nem látjuk megerősítve. Nyisd meg a levelet, és koppints a linkre.';
        });
      }
    } catch (e) {
      if (!silent && mounted) {
        setState(() {
          _error = true;
          _message = '$e';
        });
      }
    } finally {
      if (!silent && mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await Account.instance.sendVerification();
      if (!mounted) return;
      setState(() {
        _error = false;
        _message = 'Elküldtük az új levelet. Nézd meg a spam mappát is!';
        _cooldown = 60;
      });
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted || _cooldown <= 1) {
          t.cancel();
          if (mounted) setState(() => _cooldown = 0);
        } else {
          setState(() => _cooldown--);
        }
      });
    } on AccountException catch (e) {
      if (mounted) {
        setState(() {
          _error = true;
          _message = e.message;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(gradient: AppColors.headerGradient, borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.mark_email_unread_outlined, color: Colors.white, size: 38),
            ),
            const SizedBox(height: 24),
            Text('Erősítsd meg az e-mail-címed', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('Küldtünk egy levelet ide:', style: TextStyle(color: AppColors.textMuted, fontSize: 16, height: 1.4)),
            Text(widget.email, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 16),
            _step(theme, '1', 'Nyisd meg a levelet (nézd meg a spam mappát is).'),
            _step(theme, '2', 'Koppints a benne lévő megerősítő linkre.'),
            _step(theme, '3', 'Gyere vissza ide: az app magától továbblép.'),
            if (_message != null) ...[
              const SizedBox(height: 8),
              Text(
                _message!,
                style: TextStyle(
                  color: _error ? AppColors.danger : AppColors.status(AvailabilityStatus.available),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : () => _check(),
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('Megerősítettem'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: _busy || _cooldown > 0 ? null : _resend,
              child: Text(_cooldown > 0 ? 'Új levél kérése ($_cooldown mp)' : 'Levél újraküldése'),
            ),
            const SizedBox(height: 4),
            TextButton(onPressed: Account.instance.logout, child: const Text('Rossz az e-mail-cím? Kijelentkezés')),
          ],
        ),
      ),
    );
  }

  Widget _step(ThemeData theme, String number, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: AppColors.primary,
          child: Text(
            number,
            style: TextStyle(color: AppColors.onPrimary, fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15, height: 1.35))),
      ],
    ),
  );
}

/// Megerősítés után: „Sikeres regisztráció”, a Tovább után indul az app (és az első lépések).
class RegistrationSuccessScreen extends StatelessWidget {
  const RegistrationSuccessScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: AppColors.headerGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.verified_outlined, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 24),
                  Text('Sikeres regisztráció!', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Megerősítettük az e-mail-címed. Következnek az első lépések: pár kérdés, hogy a barátaid felismerjenek.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 16, height: 1.4),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(112, 48)),
                  onPressed: onContinue,
                  child: const Text('Tovább'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
