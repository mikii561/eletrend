import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../store.dart';
import '../theme.dart';

/// A napló zárolása: feloldás PIN-kóddal vagy ujjlenyomattal.
class JournalLock {
  static final _auth = LocalAuthentication();

  /// Van-e a telefonon használható ujjlenyomat/arcfelismerés. Böngészőben nincs.
  static Future<bool> biometricsAvailable() async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _biometric() async {
    try {
      return await _auth.authenticate(localizedReason: 'Oldd fel a naplódat', biometricOnly: true);
    } catch (_) {
      return false;
    }
  }

  /// Feloldja a naplót, ha zárolva van. Igazat ad, ha utána látható.
  static Future<bool> ensureUnlocked(BuildContext context) async {
    final store = StoreScope.of(context);
    if (store.journalVisible) return true;
    final ok = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PinScreen.unlock()));
    return ok == true;
  }

  /// Új PIN megadása kétszer; igazat ad, ha beállította.
  static Future<bool> createPin(BuildContext context) async {
    final ok = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PinScreen.create()));
    return ok == true;
  }
}

/// Négyjegyű PIN beírása saját számbillentyűzettel.
class PinScreen extends StatefulWidget {
  const PinScreen.unlock({super.key}) : creating = false;
  const PinScreen.create({super.key}) : creating = true;

  final bool creating;

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> with SingleTickerProviderStateMixin {
  static const length = 4;

  String _pin = '';
  String? _first;
  String? _error;
  bool _biometrics = false;
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

  @override
  void initState() {
    super.initState();
    // Az első képkocka után, mert az adatokat itt még nem érjük el.
    if (!widget.creating) WidgetsBinding.instance.addPostFrameCallback((_) => _offerBiometrics());
  }

  Future<void> _offerBiometrics() async {
    if (!mounted) return;
    final store = StoreScope.of(context);
    if (!store.useBiometrics || !await JournalLock.biometricsAvailable()) return;
    setState(() => _biometrics = true);
    await _tryBiometrics();
  }

  Future<void> _tryBiometrics() async {
    final store = StoreScope.of(context);
    if (await JournalLock._biometric() && mounted) {
      store.unlockJournal();
      Navigator.pop(context, true);
    }
  }

  void _type(String digit) {
    if (_pin.length >= length) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == length) Future.delayed(const Duration(milliseconds: 120), _complete);
  }

  void _complete() {
    if (!mounted) return;
    final store = StoreScope.of(context);
    if (widget.creating) {
      if (_first == null) {
        setState(() {
          _first = _pin;
          _pin = '';
        });
      } else if (_first == _pin) {
        store.setPin(_pin);
        Navigator.pop(context, true);
      } else {
        _fail('A két PIN nem egyezik. Kezdjük újra!');
        _first = null;
      }
    } else if (store.checkPin(_pin)) {
      store.unlockJournal();
      Navigator.pop(context, true);
    } else {
      _fail('Hibás PIN-kód');
    }
  }

  void _fail(String message) {
    _shake.forward(from: 0);
    setState(() {
      _pin = '';
      _error = message;
    });
  }

  Future<void> _forgot() async {
    final store = StoreScope.of(context);
    final erase = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elfelejtetted a PIN-kódot?'),
        content: Text(
          'A PIN-kódot sehol nem tároljuk visszafejthetően, ezért nem lehet visszaállítani. '
          'A zárat csak úgy tudod kikapcsolni, ha törlöd a naplóbejegyzéseidet (${store.journal.length} db). '
          'A szokásaid és a programjaid megmaradnak.\n\nHa van biztonsági mentésed, utána abból visszatöltheted.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Mégse')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade400),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Napló törlése'),
          ),
        ],
      ),
    );
    if (erase != true || !mounted) return;
    store.resetLockAndJournal();
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.creating
        ? (_first == null ? 'Adj meg egy 4 jegyű PIN-kódot' : 'Írd be még egyszer')
        : 'A naplód zárolva van';

    // Gépen a billentyűzettel is beírható.
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final ch = event.character;
        if (ch != null && RegExp(r'^[0-9]$').hasMatch(ch)) {
          _type(ch);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.backspace && _pin.isNotEmpty) {
          setState(() => _pin = _pin.substring(0, _pin.length - 1));
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        appBar: AppBar(leading: const CloseButton()),
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              const Text('🔒', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              AnimatedBuilder(
                animation: _shake,
                builder: (context, child) => Transform.translate(
                  offset: Offset(sin(_shake.value * pi * 6) * 12 * (1 - _shake.value), 0),
                  child: child,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < _pin.length ? AppColors.primary : Colors.transparent,
                          border: Border.all(color: AppColors.primary, width: 2),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 40,
                child: Center(
                  child: Text(
                    _error ?? '',
                    style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const Spacer(),
              for (final row in const [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
              ])
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [for (final d in row) _Key(label: d, onTap: () => _type(d))],
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _biometrics
                      ? _Key(icon: Icons.fingerprint, onTap: _tryBiometrics, tooltip: 'Ujjlenyomat')
                      : const SizedBox(width: 96, height: 76),
                  _Key(label: '0', onTap: () => _type('0')),
                  _Key(
                    icon: Icons.backspace_outlined,
                    tooltip: 'Törlés',
                    onTap: () => setState(() => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (!widget.creating) TextButton(onPressed: _forgot, child: const Text('Elfelejtettem a PIN-kódot')),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({this.label, this.icon, this.tooltip, required this.onTap});

  final String? label;
  final IconData? icon;
  final String? tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final child = InkResponse(
      onTap: onTap,
      radius: 38,
      child: SizedBox(
        width: 96,
        height: 76,
        child: Center(
          child: label != null
              ? Text(label!, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700))
              : Icon(icon, size: 28, color: AppColors.textMuted),
        ),
      ),
    );
    return tooltip == null ? child : Tooltip(message: tooltip!, child: child);
  }
}
