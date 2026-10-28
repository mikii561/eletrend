import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../account.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'auth_screen.dart';

/// Az app kapuja: bejelentkezés nélkül a regisztráció jön; bejelentkezve betölti a fiók
/// adatait, és utána a [child] (az app) következik.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late StreamSubscription<User?> _sub;
  User? _user;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _user = Account.instance.user;
    _sub = Account.instance.changes.listen(_onUser);
    if (_user != null) WidgetsBinding.instance.addPostFrameCallback((_) => _startSync(_user!));
  }

  void _onUser(User? user) {
    if (user?.uid == _user?.uid) return;
    Account.instance.sync?.stop();
    Account.instance.sync = null;
    setState(() {
      _user = user;
      _error = null;
    });
    if (user != null) _startSync(user);
  }

  Future<void> _startSync(User user) async {
    final store = StoreScope.of(context);
    final sync = CloudSync(store: store, uid: user.uid, db: Account.instance.db);
    if (sync.knownDevice) {
      // Ezen az eszközön már ehhez a fiókhoz szinkronizáltunk: azonnal mehet, a felhő a háttérben frissül.
      setState(() => Account.instance.sync = sync..listen());
      unawaited(sync.start().catchError((Object e) => debugPrint('Szinkronizálás később: $e')));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await sync.start();
      if (store.myName.isEmpty && (user.displayName ?? '').isNotEmpty) store.setMyName(user.displayName!);
      Account.instance.sync = sync..listen();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return const AuthScreen();
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const EmptyState(emoji: '📡', text: 'Nem sikerült betölteni az adataidat.\nVan internet?'),
                const SizedBox(height: 12),
                FilledButton(onPressed: () => _startSync(_user!), child: const Text('Újra')),
                TextButton(onPressed: Account.instance.logout, child: const Text('Kijelentkezés')),
              ],
            ),
          ),
        ),
      );
    }
    if (_loading || Account.instance.sync == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Adataid betöltése…', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
    }
    return widget.child;
  }
}
