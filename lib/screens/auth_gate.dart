import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../account.dart';
import '../admin.dart';
import '../friends.dart';
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
  bool _banned = false;
  StreamSubscription<void>? _inbox;
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
    _stopFriends();
    Admin.currentUid = user?.uid;
    setState(() {
      _user = user;
      _error = null;
      _banned = false;
    });
    if (user != null) _startSync(user);
  }

  Future<void> _startSync(User user) async {
    final store = StoreScope.of(context);
    Admin.currentUid = user.uid;
    unawaited(_checkAccount(user, store));
    unawaited(_startFriends(user, store));
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

  /// Barátkód, névjegy, és a barátoktól jövő meghívások figyelése.
  Future<void> _startFriends(User user, AppStore store) async {
    try {
      await Friends.instance.start(user.uid, store);
      await _inbox?.cancel();
      _inbox = Friends.instance.listenInbox();
    } catch (e) {
      debugPrint('Barátok később: $e');
    }
  }

  void _stopFriends() {
    _inbox?.cancel();
    _inbox = null;
    Friends.instance.stop();
  }

  /// Felfüggesztett-e a fiók, és az adminnak látható adatlap frissítése.
  Future<void> _checkAccount(User user, AppStore store) async {
    final banned = await Admin.instance.isBanned(user.uid);
    if (mounted && banned != _banned) setState(() => _banned = banned);
    try {
      await Admin.instance.updateProfile(
        uid: user.uid,
        email: user.email ?? '',
        store: store,
        createdAt: user.metadata.creationTime,
        force: true,
      );
    } catch (e) {
      debugPrint('Adatlap frissítése később: $e');
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    _stopFriends();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return const AuthScreen();
    if (_banned) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const EmptyState(
                  emoji: '⛔',
                  text: 'A fiókod fel van függesztve.\nHa szerinted ez tévedés, keresd az app üzemeltetőjét.',
                ),
                TextButton(onPressed: Account.instance.logout, child: const Text('Kijelentkezés')),
              ],
            ),
          ),
        ),
      );
    }
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
