import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../account.dart';
import '../admin.dart';
import '../app_navigator.dart';
import '../availability_service.dart';
import '../challenges.dart';
import '../friends.dart';
import '../notifications.dart';
import '../nudges.dart';
import '../push.dart';
import 'nudge_screens.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'auth_screen.dart';
import 'challenges_screen.dart' show ChallengeDetail;
import 'verify_email_screen.dart';

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

  /// Az új (e-mail + jelszavas) fiók e-mail-címét megerősítette-e már, és látta-e a „Sikeres regisztráció” oldalt.
  bool _verified = false;
  bool _showSuccess = false;
  StreamSubscription<void>? _inbox;
  String? _error;

  @override
  void initState() {
    super.initState();
    _user = Account.instance.user;
    _sub = Account.instance.changes.listen(_onUser);
    if (_user != null && !_awaitingVerification) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startSync(_user!));
    }
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
      _verified = false;
      _showSuccess = false;
    });
    if (user != null && !_awaitingVerification) _startSync(user);
  }

  /// Megerősítésre vár: addig nem töltünk le és nem hozunk létre semmit a fiókhoz.
  bool get _awaitingVerification => !_verified && Account.instance.needsVerification(_user);

  void _onVerified() {
    setState(() {
      _verified = true;
      _showSuccess = true;
    });
  }

  void _continueAfterSuccess() {
    setState(() => _showSuccess = false);
    _startSync(_user!);
  }

  Future<void> _startSync(User user) async {
    final store = StoreScope.of(context);
    Admin.currentUid = user.uid;
    unawaited(_checkAccount(user, store));
    // Ha már engedélyezte az értesítéseket, a token frissítése (az FCM időnként újat ad).
    unawaited(Push.register(user.uid).then((_) {}, onError: (Object e) => debugPrint('Push később: $e')));
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

  /// Barátkód, névjegy, elérhetőség, és a barátoktól jövő meghívások és bökések figyelése.
  Future<void> _startFriends(User user, AppStore store) async {
    try {
      Challenges.instance.start(user.uid, store);
      Challenges.instance.listenActivity(_onChallengeActivity);
      Nudges.instance.start(user.uid, _onNudge);
      AvailabilityService.instance.start(user.uid, store);
      Notifications.onTap = _onNotificationTap;
      if (Notifications.pendingTap case final tap?) {
        Notifications.pendingTap = null;
        unawaited(_onNotificationTap(tap));
      }
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
    Challenges.instance.stop();
    Nudges.instance.stop();
    AvailabilityService.instance.stop();
  }

  /// Új bökés: ha az app előtérben van, rövid sáv jelenik meg; ha háttérben, telefonos értesítés jön.
  void _onNudge(Nudge n) {
    final nav = appNavigatorKey.currentState;
    final foreground = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (nav == null || !foreground) {
      if (Notifications.supported) {
        Notifications.showNudge(
          n.id,
          '${n.emoji} ${n.fromName}',
          n.eventTitle == null ? n.text : '${n.text} · ${n.eventTitle}',
        );
      }
      Nudges.instance.notShown(n.id);
      return;
    }
    ScaffoldMessenger.of(nav.context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Text(n.headline),
        action: SnackBarAction(label: 'Megnyitom', onPressed: () => openNudge(nav.context, n)),
      ),
    );
    // Olvasottá csak akkor válik, ha megnyitja (a számláló addig mutatja).
  }

  /// Valaki ma megcsinálta a kihívást (és én még nem), vagy megbuzdítottak: előtérben sáv, háttérben értesítés.
  void _onChallengeActivity(ChallengeActivity a) {
    final nav = appNavigatorKey.currentState;
    final foreground = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (nav == null || !foreground) {
      if (Notifications.supported) Notifications.showChallenge(a.challenge.id, a.title, a.body);
      return;
    }
    ScaffoldMessenger.of(nav.context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Text('${a.title}\n${a.body}'),
        action: SnackBarAction(
          label: 'Megnyitom',
          onPressed: () => nav.push(MaterialPageRoute(builder: (_) => ChallengeDetail(challenge: a.challenge))),
        ),
      ),
    );
  }

  /// Értesítésre koppintva: a bökés (és a programja), illetve a kihívás megnyílik.
  Future<void> _onNotificationTap(String payload) async {
    if (payload.startsWith('challenge:')) {
      final challenge = await Challenges.instance.get(payload.substring(10));
      final nav = appNavigatorKey.currentState;
      if (challenge == null || nav == null || !nav.mounted) return;
      await nav.push(MaterialPageRoute<void>(builder: (_) => ChallengeDetail(challenge: challenge)));
      return;
    }
    if (!payload.startsWith('nudge:')) return;
    final nudge = await Nudges.instance.fetch(payload.substring(6));
    final nav = appNavigatorKey.currentState;
    if (nudge == null || nav == null || !nav.mounted) return;
    await openNudge(nav.context, nudge);
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
    if (_awaitingVerification) {
      return VerifyEmailScreen(email: _user!.email ?? '', onVerified: _onVerified);
    }
    if (_showSuccess) return RegistrationSuccessScreen(onContinue: _continueAfterSuccess);
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
              Text(
                'Adataid betöltése…',
                style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
    }
    return widget.child;
  }
}
