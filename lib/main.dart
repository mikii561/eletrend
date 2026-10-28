import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'habits_widget.dart';
import 'notifications.dart';
import 'screens/events_screen.dart';
import 'screens/habits_screen.dart';
import 'screens/journal_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/today_screen.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets/phone_frame.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('hu');
  final store = await AppStore.load();
  runApp(EletrendApp(store: store));
  // Az app megjelenése után, hogy az engedélykérő ablak az app fölött jelenjen meg.
  unawaited(Notifications.init(store));
  unawaited(HabitsWidget.init(store));
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
          home: store.needsOnboarding ? const OnboardingScreen() : const HomeShell(),
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
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
      // Közben a widgeten is kipipálhattál valamit.
      store.reload();
    }
  }

  void _goTo(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final screens = [TodayScreen(onNavigate: _goTo), const EventsScreen(), const HabitsScreen(), const JournalScreen()];
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
        ],
      ),
    );
  }
}
