import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/events_screen.dart';
import 'screens/habits_screen.dart';
import 'screens/journal_screen.dart';
import 'screens/today_screen.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets/phone_frame.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('hu');
  final store = await AppStore.load();
  runApp(EletrendApp(store: store));
}

class EletrendApp extends StatelessWidget {
  const EletrendApp({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: MaterialApp(
        title: 'Életrend',
        debugShowCheckedModeBanner: false,
        locale: const Locale('hu'),
        supportedLocales: const [Locale('hu')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: buildTheme(),
        builder: (context, child) => PhoneFrame(child: child!),
        home: const HomeShell(),
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

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _goTo(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final screens = [
      TodayScreen(onNavigate: _goTo),
      const EventsScreen(),
      const HabitsScreen(),
      const JournalScreen(),
    ];
    return Scaffold(
      body: screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.wb_sunny_outlined), selectedIcon: Icon(Icons.wb_sunny), label: 'Ma'),
          NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: 'Programok'),
          NavigationDestination(icon: Icon(Icons.check_circle_outline), selectedIcon: Icon(Icons.check_circle), label: 'Szokások'),
          NavigationDestination(icon: Icon(Icons.book_outlined), selectedIcon: Icon(Icons.book), label: 'Napló'),
        ],
      ),
    );
  }
}
