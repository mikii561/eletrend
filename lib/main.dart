import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'admin.dart';
import 'badges.dart';
import 'bumps.dart';
import 'account.dart';
import 'app_navigator.dart';
import 'firebase_options.dart';
import 'friends.dart';
import 'habits_widget.dart';
import 'notifications.dart';
import 'screens/auth_gate.dart';
import 'screens/badges_screen.dart';
import 'screens/events_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/habits_screen.dart';
import 'screens/invite_screen.dart';
import 'screens/journal_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/today_screen.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets/phone_frame.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Az élesben futó app a hibákat az adminnak jelenti (lásd Admin felület → Hibák).
  Admin.reportingEnabled = kReleaseMode;
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    previousOnError?.call(details);
    unawaited(Admin.instance.reportError(details.exception, details.stack));
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(Admin.instance.reportError(error, stack));
    return false;
  };
  await initializeDateFormatting('hu');
  final store = await AppStore.load();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Böngészőben a bejelentkezés kis késéssel töltődik vissza; megvárjuk, hogy ne villanjon fel a regisztráció.
  await FirebaseAuth.instance.authStateChanges().first;
  runApp(EletrendApp(store: store));
  _openInviteFromLink();
  // Az app megjelenése után, hogy az engedélykérő ablak az app fölött jelenjen meg.
  unawaited(Notifications.init(store));
  unawaited(HabitsWidget.init(store));
}

/// Ha meghívólinkkel nyitották meg a weboldalt (…/eletrend/?e=azonosító), rögtön a meghívás jön.
void _openInviteFromLink() {
  if (!kIsWeb) return;
  final id = Uri.base.queryParameters['e'];
  if (id == null || !RegExp(r'^[A-Za-z0-9]{10,40}$').hasMatch(id)) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    appNavigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => InviteScreen(eventId: id)));
  });
}

class EletrendApp extends StatelessWidget {
  const EletrendApp({super.key, required this.store});

  final AppStore store;

  /// Beállítja az [AppColors] módját. Ha váltott, minden képernyőt újrarajzol,
  /// hogy a const-ként megmaradt widgetek is az új színeket kapják.
  static void _applyBrightness(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (AppColors.dark == dark) return;
    AppColors.dark = dark;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      void rebuild(Element e) {
        e.markNeedsBuild();
        e.visitChildren(rebuild);
      }

      (context as Element).visitChildren(rebuild);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      // A téma és a kezdőképernyő a beállításoktól függ, ezért változáskor újraépül.
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) => MaterialApp(
          title: 'Életrend',
          navigatorKey: appNavigatorKey,
          debugShowCheckedModeBanner: false,
          locale: const Locale('hu'),
          supportedLocales: const [Locale('hu')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: buildTheme(),
          darkTheme: buildTheme(dark: true),
          themeMode: store.themeMode,
          builder: (context, child) {
            _applyBrightness(context);
            return PhoneFrame(child: child!);
          },
          home: AuthGate(child: store.needsOnboarding ? const OnboardingScreen() : const HomeShell()),
        ),
      ),
    );
  }
}

/// Alsó navigációs sáv a négy fő képernyővel.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  AppStore? _store;
  Timer? _badgeCheck;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = StoreScope.of(context);
    if (store != _store) {
      _store?.removeListener(_onStoreChange);
      _store = store..addListener(_onStoreChange);
      _onStoreChange();
    }
  }

  void _onStoreChange() {
    _badgeCheck?.cancel();
    _badgeCheck = Timer(const Duration(milliseconds: 800), _checkBadges);
  }

  /// Új jelvény? Ünnepeljük. (Elsőre a már meglévőket csendben „láttuk”-nak vesszük.)
  void _checkBadges() {
    final store = _store;
    if (store == null || !mounted) return;
    final earned = earnedBadges(store);
    final seen = store.seenBadges;
    if (seen == null) {
      store.markBadgesSeen(earned);
      return;
    }
    final fresh = [for (final a in achievements) if (earned.contains(a.id) && !seen.contains(a.id)) a];
    if (fresh.isEmpty) return;
    store.markBadgesSeen(fresh.map((a) => a.id));
    showBadgeEarned(context, fresh.first, more: fresh.length - 1);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _badgeCheck?.cancel();
    _store?.removeListener(_onStoreChange);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Ha az app háttérbe kerül (vagy böngészőben másik fülre váltasz), a napló újra zárolódik.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final store = StoreScope.of(context);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      store.lockJournal();
    } else if (state == AppLifecycleState.resumed) {
      // Közben a widgeten is kipipálhattál valamit, vagy egy másik eszközön módosítottál.
      store.reload().then((_) => Account.instance.sync?.refresh()).catchError((Object e) {
        debugPrint('Frissítés a felhőből később: $e');
      });
      Bumps.instance.checkNow().catchError((Object e) => debugPrint('Bumpok később: $e'));
      final user = Account.instance.user;
      if (user != null) {
        Admin.instance
            .updateProfile(uid: user.uid, email: user.email ?? '', store: store)
            .catchError((Object e) => debugPrint('Adatlap később: $e'));
      }
    }
  }

  void _goTo(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final screens = [
      TodayScreen(onNavigate: _goTo),
      const EventsScreen(),
      const HabitsScreen(),
      const JournalScreen(),
      const FriendsScreen(),
    ];
    return Scaffold(
      body: screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.wb_sunny_outlined), selectedIcon: Icon(Icons.wb_sunny), label: 'Ma'),
          NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: 'Programok'),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: 'Szokások',
          ),
          NavigationDestination(icon: Icon(Icons.book_outlined), selectedIcon: Icon(Icons.book), label: 'Napló'),
          NavigationDestination(
            icon: _FriendsTabIcon(selected: false),
            selectedIcon: _FriendsTabIcon(selected: true),
            label: 'Barátok',
          ),
        ],
      ),
    );
  }
}

/// A Barátok fül ikonja; ha barátjelölés vár rád, a számát is mutatja.
class _FriendsTabIcon extends StatefulWidget {
  const _FriendsTabIcon({required this.selected});

  final bool selected;

  @override
  State<_FriendsTabIcon> createState() => _FriendsTabIconState();
}

class _FriendsTabIconState extends State<_FriendsTabIcon> {
  Stream<List<FriendRequest>>? _requests;

  @override
  Widget build(BuildContext context) {
    // A barátok szolgáltatás a bejelentkezés után indul el; addig csak az ikon látszik.
    if (_requests == null && Friends.instance.ready) _requests = Friends.instance.watchRequests();
    final icon = Icon(widget.selected ? Icons.people_alt : Icons.people_alt_outlined);
    if (_requests == null) return icon;
    return StreamBuilder<List<FriendRequest>>(
      stream: _requests,
      builder: (context, snap) {
        final n = snap.data?.length ?? 0;
        return n == 0 ? icon : Badge(label: Text('$n'), child: icon);
      },
    );
  }
}
