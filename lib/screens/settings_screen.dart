import 'package:flutter/material.dart';

import '../backup.dart';
import '../habits_widget.dart';
import '../notifications.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'account_section.dart';
import 'bump_screens.dart';
import 'pin_screen.dart';
import 'tags_screen.dart';

/// Beállítások: a fiók, alatta témánként egy-egy aloldal, hogy ne egy hosszú lista legyen.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _themeNames = {ThemeMode.system: 'Automatikus', ThemeMode.light: 'Világos', ThemeMode.dark: 'Sötét'};

  void _open(BuildContext context, String title, List<Widget> Function(BuildContext, AppStore) children) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _SettingsPage(title: title, children: children),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final on = Feature.values.where(store.shows).length;
    final notifications = [
      if (store.dailyReminder) 'esti ${store.reminderTime.format(context)}',
      if (store.weeklySummary) 'heti összefoglaló',
      if (store.eventReminders) 'programok',
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Beállítások')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const AccountSection(),
          const SectionTitle('Általános'),
          Card(
            child: Column(
              children: [
                _GroupTile(
                  icon: Icons.notifications_outlined,
                  title: 'Értesítések',
                  subtitle: notifications.isEmpty ? 'Kikapcsolva' : notifications.join(', '),
                  onTap: () => _open(context, 'Értesítések', _notifications),
                ),
                _GroupTile(
                  icon: Icons.palette_outlined,
                  title: 'Megjelenés',
                  subtitle: _themeNames[store.themeMode]!,
                  onTap: () => _open(context, 'Megjelenés', _appearance),
                ),
                _GroupTile(
                  icon: Icons.book_outlined,
                  title: 'Napló és hangulatok',
                  subtitle: store.journalLocked ? 'Saját arcok, címkék · PIN-nel zárva' : 'Saját arcok, címkék, zárolás',
                  onTap: () => _open(context, 'Napló és hangulatok', _journal),
                ),
                _GroupTile(
                  icon: Icons.tune,
                  title: 'Funkciók',
                  subtitle: '$on/${Feature.values.length} bekapcsolva · azt lásd, amit használsz',
                  onTap: () => _open(context, 'Funkciók', _features),
                ),
                if (store.shows(Feature.bumps))
                  _GroupTile(
                    icon: Icons.waving_hand_outlined,
                    title: 'Bumpok',
                    subtitle: 'Fogadás, animációk',
                    onTap: () => _open(context, 'Bumpok', (_, _) => const [BumpSettingsCard()]),
                  ),
                _GroupTile(
                  icon: Icons.save_outlined,
                  title: 'Adatok és mentés',
                  subtitle: 'Mentés fájlba, visszatöltés, kezdőképernyő',
                  onTap: () => _open(context, 'Adatok és mentés', _data),
                  last: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Aloldalak

  static Future<void> _pickTime(BuildContext context, AppStore store) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: store.reminderTime,
      helpText: 'Mikor emlékeztesselek?',
    );
    if (picked != null) store.setReminders(time: picked);
  }

  /// Bekapcsoláskor engedélyt kér; ha nem kapunk, szólunk.
  static Future<void> _enable(BuildContext context, void Function() apply) async {
    apply();
    if (!Notifications.supported) return;
    final ok = await Notifications.requestPermission();
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Az értesítések le vannak tiltva. A telefon Beállítások → Alkalmazások → Életrend menüjében engedélyezheted.',
          ),
        ),
      );
    }
  }

  static List<Widget> _notifications(BuildContext context, AppStore store) => [
        if (!Notifications.supported)
          Card(
            color: AppColors.accent.withValues(alpha: 0.12),
            child: const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Böngészőben az app nem tud értesítést küldeni, ezért ezek a Ma képernyőn jelennek meg.'),
            ),
          ),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const IconTile(Icons.nightlight_outlined),
                title: const Text('Esti emlékeztető'),
                subtitle: const Text('Ha még van kipipálatlan célod, vagy nem írtál naplót. Ha mindennel kész vagy, nem zavar.'),
                value: store.dailyReminder,
                onChanged: (on) =>
                    on ? _enable(context, () => store.setReminders(daily: true)) : store.setReminders(daily: false),
              ),
              ListTile(
                enabled: store.dailyReminder,
                leading: const SizedBox(width: 36),
                title: const Text('Időpont'),
                trailing: Text(
                  store.reminderTime.format(context),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                onTap: () => _pickTime(context, store),
              ),
            ],
          ),
        ),
        Card(
          child: SwitchListTile(
            secondary: const IconTile(Icons.insights_outlined),
            title: const Text('Heti összefoglaló'),
            subtitle: const Text('Vasárnap este 19:00-kor: hogy ment a hét a céljaiddal és a hangulatoddal.'),
            value: store.weeklySummary,
            onChanged: (on) => on ? _enable(context, () => store.setWeeklySummary(true)) : store.setWeeklySummary(false),
          ),
        ),
        Card(
          child: SwitchListTile(
            secondary: const IconTile(Icons.celebration_outlined),
            title: const Text('Program emlékeztetők'),
            subtitle: const Text('Előző este 18:00-kor, és 1 órával a kezdés előtt.'),
            value: store.eventReminders,
            onChanged: (on) =>
                on ? _enable(context, () => store.setReminders(events: true)) : store.setReminders(events: false),
          ),
        ),
        if (store.shows(Feature.checkIn))
          Card(
            child: SwitchListTile(
              secondary: const IconTile(Icons.mood_outlined),
              title: const Text('„Hogy vagy most?” napközben'),
              subtitle: const Text('11:00-kor és 15:00-kor rákérdez a telefon.'),
              value: store.checkInReminders,
              onChanged: (on) =>
                  on ? _enable(context, () => store.setCheckInReminders(true)) : store.setCheckInReminders(false),
            ),
          ),
        if (Notifications.supported) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () async {
              if (await Notifications.requestPermission()) {
                await Notifications.showTest();
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Előbb engedélyezd az értesítéseket a telefon beállításaiban.')),
                );
              }
            },
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Próba értesítés küldése'),
          ),
        ],
      ];

  static List<Widget> _appearance(BuildContext context, AppStore store) => [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('Auto')),
                  ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Világos')),
                  ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Sötét')),
                ],
                selected: {store.themeMode},
                onSelectionChanged: (s) => store.setThemeMode(s.first),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Text(
            'Az „Auto” a telefon beállítását követi.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      ];

  static List<Widget> _journal(BuildContext context, AppStore store) => [
        Card(
          child: ListTile(
            leading: const IconTile(Icons.sell_outlined),
            title: const Text('Hangulatok és címkék'),
            subtitle: Text('Saját arcok a napokhoz, ${store.visibleTags.length} látható címke'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TagsScreen())),
          ),
        ),
        const SectionTitle('Zárolás'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const IconTile(Icons.lock_outline),
                title: const Text('PIN-kód a naplóhoz'),
                subtitle: const Text('A Napló csak PIN-kóddal nyílik meg. Ha az app háttérbe kerül, újra bezár.'),
                value: store.journalLocked,
                onChanged: (on) async {
                  if (on) {
                    await JournalLock.createPin(context);
                  } else if (await JournalLock.ensureUnlocked(context)) {
                    store.clearPin();
                  }
                },
              ),
              if (store.journalLocked) ...[
                ListTile(
                  leading: const SizedBox(width: 36, child: Icon(Icons.pin_outlined)),
                  title: const Text('PIN-kód módosítása'),
                  onTap: () async {
                    if (await JournalLock.ensureUnlocked(context) && context.mounted) {
                      await JournalLock.createPin(context);
                    }
                  },
                ),
                FutureBuilder(
                  future: JournalLock.biometricsAvailable(),
                  builder: (context, snap) => snap.data != true
                      ? const SizedBox.shrink()
                      : SwitchListTile(
                          secondary: const SizedBox(width: 36, child: Icon(Icons.fingerprint)),
                          title: const Text('Feloldás ujjlenyomattal'),
                          value: store.useBiometrics,
                          onChanged: store.setUseBiometrics,
                        ),
                ),
              ],
            ],
          ),
        ),
      ];

  static List<Widget> _features(BuildContext context, AppStore store) => [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            'Kapcsold ki, amit nem használsz, és eltűnik az appból. Az adatok megmaradnak, bármikor visszakapcsolhatod.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
        Card(
          child: Column(
            children: [
              for (final f in Feature.values)
                SwitchListTile(
                  secondary: IconTile(f.icon),
                  title: Text(f.title),
                  subtitle: Text(f.description),
                  value: store.shows(f),
                  onChanged: (on) => store.setFeature(f, on),
                ),
            ],
          ),
        ),
      ];

  static List<Widget> _data(BuildContext context, AppStore store) => [
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const IconTile(Icons.download_outlined),
                title: const Text('Mentés fájlba'),
                subtitle: const Text('Minden adatod egy fájlban. Tedd el, vagy vidd át egy másik eszközre.'),
                onTap: () => Backup.export(context, store),
              ),
              ListTile(
                leading: const IconTile(Icons.upload_outlined),
                title: const Text('Visszatöltés fájlból'),
                subtitle: const Text('Egy korábbi mentés visszaállítása.'),
                onTap: () => Backup.restore(context, store),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Text(
            'A fiókodba minden automatikusan mentődik. A napló fotói nincsenek a fájlban, azok a telefonon maradnak.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
        FutureBuilder(
          future: HabitsWidget.canPin(),
          builder: (context, snap) => snap.data != true
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle('Kezdőképernyő'),
                    Card(
                      child: ListTile(
                        leading: const IconTile(Icons.widgets_outlined),
                        title: const Text('Célok a kezdőképernyőn'),
                        subtitle: const Text('Widget, amin a mai céljaid az app megnyitása nélkül kipipálhatók.'),
                        trailing: const Icon(Icons.add_to_home_screen),
                        onTap: HabitsWidget.pin,
                      ),
                    ),
                  ],
                ),
        ),
      ];
}

/// Egy beállításcsoport sora a főoldalon.
class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.icon, required this.title, required this.subtitle, required this.onTap, this.last = false});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          ListTile(
            leading: IconTile(icon),
            title: Text(title),
            subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_right),
            onTap: onTap,
          ),
          if (!last) const Divider(indent: 68),
        ],
      );
}

/// Egy beállításcsoport oldala; a store változásakor újraépül.
class _SettingsPage extends StatelessWidget {
  const _SettingsPage({required this.title, required this.children});

  final String title;
  final List<Widget> Function(BuildContext, AppStore) children;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: children(context, StoreScope.of(context)),
        ),
      );
}
