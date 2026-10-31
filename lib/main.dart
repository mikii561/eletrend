import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'account.dart';
import 'admin.dart';
import 'app_navigator.dart';
import 'firebase_options.dart';
import 'friends.dart';
import 'notifications.dart';
import 'nudges.dart';
import 'screens/auth_gate.dart';
import 'screens/calendar_screen.dart';
import 'screens/create_sheet.dart';
import 'screens/friends_screen.dart';
import 'screens/home_screen.dart';
import 'screens/invite_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_screen.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets/app_tour.dart';
import 'widgets/common.dart';
import 'widgets/motion.dart';
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
  runApp(LifeupApp(store: store));
  _openInviteFromLink();
  unawaited(Notifications.init(store));
}

/// Ha meghívólinkkel nyitották meg a weboldalt (…/eletrend/?e=azonosító), rögtön a meghívás jön.
void _openInviteFromLink() {
  if (!kIsWeb) return;
  final tap = Uri.base.queryParameters['n'];
  if (tap != null && RegExp(r'^nudge:[A-Za-z0-9_]{10,80}$').hasMatch(tap)) Notifications.pendingTap = tap;
  final id = Uri.base.queryParameters['e'];
  if (id == null || !RegExp(r'^[A-Za-z0-9]{10,40}$').hasMatch(id)) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    appNavigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => InviteScreen(eventId: id)));
  });
}

class LifeupApp extends StatelessWidget {
  const LifeupApp({super.key, required this.store});

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
          title: 'LIFEUP',
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

/// Az alsó menü: Főoldal, Naptár, Létrehozás (kiemelt), Barátok, Profil.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  /// A bemutató újraindítása (pl. a Profilból).
  static void startTour(BuildContext context) => context.findAncestorStateOfType<_HomeShellState>()?.startTour();

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  bool _touring = false;

  /// A középső helyen a Létrehozás gomb van, nem képernyő.
  static const _create = 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Az első megnyitáskor (a bevezető után) magától jön a bemutató.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !StoreScope.of(context).tourDone) startTour();
    });
  }

  /// A Főoldalra vált, és végigvezet a fő részeken.
  void startTour() {
    if (_touring) return;
    _touring = true;
    setState(() => _index = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showAppTour(
        context,
        appTourSteps,
        onDone: () {
          _touring = false;
          if (mounted) StoreScope.of(context).setTourDone(true);
        },
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Visszatéréskor: a máshol történt változások le, a közben jött bökések, az adatlap frissítése.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final store = StoreScope.of(context);
    Account.instance.sync?.refresh().catchError((Object e) => debugPrint('Frissítés a felhőből később: $e'));
    Nudges.instance.checkNow().catchError((Object e) => debugPrint('Bökések később: $e'));
    Friends.instance.refreshCache().catchError((Object e) => debugPrint('Barátok később: $e'));
    final user = Account.instance.user;
    if (user != null) {
      Admin.instance
          .updateProfile(uid: user.uid, email: user.email ?? '', store: store)
          .catchError((Object e) => debugPrint('Adatlap később: $e'));
    }
  }

  void _select(int i) {
    if (i == _create) {
      showCreateSheet(context);
      return;
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fülváltáskor az új fül lágyan beúszik.
      // (A régi azonnal eltűnik, így sosem él egyszerre két példány ugyanabból a képernyőből.)
      body: FadeSlideIn(
        key: ValueKey(_index),
        offset: 6,
        child: switch (_index) {
          1 => const CalendarScreen(),
          3 => const FriendsScreen(),
          4 => const ProfileScreen(),
          _ => HomeScreen(onNavigate: _select),
        },
      ),
      bottomNavigationBar: NavigationBar(
        key: TourKeys.navBar,
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          const NavigationDestination(
            icon: _HomeTabIcon(selected: false),
            selectedIcon: _HomeTabIcon(selected: true),
            label: 'Főoldal',
          ),
          const NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Naptár',
          ),
          NavigationDestination(
            icon: const _CreateButton(),
            label: 'Létrehozás',
            tooltip: 'Új bejegyzés, feladat, közös program',
          ),
          const NavigationDestination(
            icon: _FriendsTabIcon(selected: false),
            selectedIcon: _FriendsTabIcon(selected: true),
            label: 'Barátok',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

/// A kiemelt, kerek Létrehozás gomb a menü közepén.
class _CreateButton extends StatelessWidget {
  const _CreateButton();

  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 36,
    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(14)),
    child: Icon(Icons.add, color: AppColors.onPrimary, size: 26),
  );
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
  Stream<int>? _nudges;

  @override
  Widget build(BuildContext context) {
    // A barátok szolgáltatás a bejelentkezés után indul el; addig csak az ikon látszik.
    if (_requests == null && Friends.instance.ready) _requests = Friends.instance.watchRequests();
    if (_nudges == null && Nudges.instance.ready) _nudges = Nudges.instance.watchUnseenCount();
    final icon = Icon(widget.selected ? Icons.people_alt : Icons.people_alt_outlined);
    // Szám: függő barátjelölések + olvasatlan bökések.
    return StreamBuilder<List<FriendRequest>>(
      stream: _requests,
      builder: (context, requests) => StreamBuilder<int>(
        stream: _nudges,
        builder: (context, nudges) => CountBadge(
          count: (requests.data?.length ?? 0) + (nudges.data ?? 0),
          label: 'új jelölés vagy bökés',
          child: icon,
        ),
      ),
    );
  }
}

/// A Főoldal fül ikonja: a még meg nem nyitott meghívások száma.
class _HomeTabIcon extends StatelessWidget {
  const _HomeTabIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => CountBadge(
        count: StoreScope.of(context).unseenInvites().length,
        label: 'új meghívás',
        child: Icon(selected ? Icons.home : Icons.home_outlined),
      );
}
