import 'package:flutter/material.dart';

import '../notifications.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/tag_icon.dart';

/// Pár cél, amivel könnyű elkezdeni.
const suggestedHabits = [
  '💧 2 liter víz',
  '🚶 10 perc séta',
  '📖 10 perc olvasás',
  '🧘 5 perc meditáció',
  '🍎 Gyümölcs vagy zöldség',
  '😴 Lefekvés éjfél előtt',
  '📵 Telefonmentes este',
  '🏋️ Edzés',
];

/// Bemutató az első indításkor, három lépésben: célok, napló, mit szeretnél látni.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _steps = 3;
  final _pages = PageController();
  int _page = 0;
  final Set<String> _picked = {suggestedHabits[0], suggestedHabits[1]};

  void _finish() {
    StoreScope.of(context).finishOnboarding(
      habits: [
        for (final h in suggestedHabits)
          if (_picked.contains(h)) h,
      ],
    );
  }

  void _go(int page) =>
      _pages.animateToPage(page, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _steps - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Lépésjelző és vissza gomb
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: _page == 0
                        ? null
                        : IconButton(
                            tooltip: 'Vissza',
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () => _go(_page - 1),
                          ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        for (var i = 0; i < _steps; i++)
                          Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              height: 4,
                              decoration: BoxDecoration(
                                color: i <= _page ? AppColors.primary : AppColors.divider,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_page + 1}/$_steps',
                    style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _Step(
                    icon: Icons.check_circle_outline,
                    title: 'Üdv az Életrendben!',
                    text: 'Kezdjük a céljaiddal. Válaszd ki, mit szeretnél követni, később bármikor módosíthatod.',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final h in suggestedHabits)
                          FilterChip(
                            label: Text(h),
                            selected: _picked.contains(h),
                            onSelected: (on) => setState(() => on ? _picked.add(h) : _picked.remove(h)),
                          ),
                      ],
                    ),
                  ),
                  const _Step(
                    icon: Icons.book_outlined,
                    title: 'Egy perc este',
                    text:
                        'Jelöld, milyen napod volt, és írd le, miért vagy hálás. '
                        'A statisztika idővel megmutatja, mi tesz jót neked.',
                    child: _JournalStep(),
                  ),
                  const _Step(
                    icon: Icons.tune,
                    title: 'Szabd magadra',
                    text:
                        'Programok a barátaiddal és sok más. Kapcsold ki, ami nem érdekel, '
                        'később a Beállításokban visszakapcsolhatod.',
                    child: _FeatureStep(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: FilledButton(
                onPressed: last ? _finish : () => _go(_page + 1),
                child: Text(
                  last ? 'Kezdjük!' : (_page == 0 && _picked.isNotEmpty ? 'Tovább ${_picked.length} céllal' : 'Tovább'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Egy lépés: ikon, cím, magyarázat és a lépés saját tartalma.
class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.title, required this.text, required this.child});

  final IconData icon;
  final String title;
  final String text;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 20),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(text, style: TextStyle(color: AppColors.textMuted, fontSize: 16, height: 1.45)),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}

/// Napló lépés: az arcok előnézete és az esti emlékeztető.
class _JournalStep extends StatelessWidget {
  const _JournalStep();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
            child: Column(
              children: [
                Text('Milyen napod van?', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [for (var m = 1; m <= 5; m++) MoodFace(m, size: 32)],
                ),
                const SizedBox(height: 10),
                Text(
                  'Az arcokra később saját képet is tehetsz.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Esti emlékeztető'),
                subtitle: Text(
                  Notifications.supported
                      ? 'Csak ha még nem írtál naplót vagy van kipipálatlan célod.'
                      : 'Böngészőben a Ma képernyőn jelenik meg.',
                ),
                value: store.dailyReminder,
                onChanged: (on) {
                  store.setReminders(daily: on);
                  if (on && Notifications.supported) Notifications.requestPermission();
                },
              ),
              if (store.dailyReminder)
                ListTile(
                  title: const Text('Időpont'),
                  trailing: Text(
                    store.reminderTime.format(context),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: store.reminderTime);
                    if (t != null) store.setReminders(time: t);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Funkciók lépés: mi jelenjen meg az appban.
class _FeatureStep extends StatelessWidget {
  const _FeatureStep();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Card(
      child: Column(
        children: [
          for (final f in Feature.values)
            SwitchListTile(
              dense: true,
              secondary: Icon(f.icon, color: AppColors.textMuted),
              title: Text(f.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              value: store.shows(f),
              onChanged: (on) => store.setFeature(f, on),
            ),
        ],
      ),
    );
  }
}
