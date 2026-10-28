import 'package:flutter/material.dart';

import '../backup.dart';
import '../habits_widget.dart';
import '../notifications.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'pin_screen.dart';
import 'tags_screen.dart';

/// Beállítások: emlékeztető értesítések.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _pickTime(BuildContext context, AppStore store) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: store.reminderTime,
      helpText: 'Mikor emlékeztesselek?',
    );
    if (picked != null) store.setReminders(time: picked);
  }

  /// Bekapcsoláskor engedélyt kér; ha nem kapunk, szólunk.
  Future<void> _enable(BuildContext context, void Function() apply) async {
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

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Beállítások')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          if (!Notifications.supported)
            Card(
              color: AppColors.accent.withValues(alpha: 0.15),
              child: const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Az értesítések csak a telefonon működnek, böngészőben nem.'),
              ),
            ),
          const SectionTitle('Napi emlékeztető'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Text('🌙', style: TextStyle(fontSize: 24)),
                  title: const Text('Esti emlékeztető', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text(
                    'Ha még van kipipálatlan szokásod, vagy nem írtál naplót. Ha mindennel kész vagy, nem zavar.',
                  ),
                  value: store.dailyReminder,
                  onChanged: (on) =>
                      on ? _enable(context, () => store.setReminders(daily: true)) : store.setReminders(daily: false),
                ),
                ListTile(
                  enabled: store.dailyReminder,
                  leading: const Icon(Icons.schedule, color: AppColors.primary),
                  title: const Text('Időpont'),
                  trailing: Text(
                    store.reminderTime.format(context),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  onTap: () => _pickTime(context, store),
                ),
              ],
            ),
          ),
          const SectionTitle('Programok'),
          Card(
            child: SwitchListTile(
              secondary: const Text('🎉', style: TextStyle(fontSize: 24)),
              title: const Text('Program emlékeztetők', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Előző este 18:00-kor, és 1 órával a kezdés előtt.'),
              value: store.eventReminders,
              onChanged: (on) =>
                  on ? _enable(context, () => store.setReminders(events: true)) : store.setReminders(events: false),
            ),
          ),
          if (Notifications.supported) ...[
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
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
          const SectionTitle('Megjelenés'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_outlined),
                      label: Text('Auto'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined),
                      label: Text('Világos'),
                    ),
                    ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Sötét')),
                  ],
                  selected: {store.themeMode},
                  onSelectionChanged: (s) => store.setThemeMode(s.first),
                ),
              ),
            ),
          ),
          const SectionTitle('Napló'),
          Card(
            child: ListTile(
              leading: const Text('🏷️', style: TextStyle(fontSize: 24)),
              title: const Text('Hangulatok és címkék', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('Saját arcok a napokhoz, ${store.visibleTags.length} látható címke'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TagsScreen())),
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
                          leading: const Text('📱', style: TextStyle(fontSize: 24)),
                          title: const Text('Szokások a kezdőképernyőn', style: TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: const Text('Widget, amin a mai szokásaid az app megnyitása nélkül kipipálhatók.'),
                          trailing: const Icon(Icons.add_to_home_screen),
                          onTap: HabitsWidget.pin,
                        ),
                      ),
                    ],
                  ),
          ),
          const SectionTitle('Napló zárolása'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Text('🔒', style: TextStyle(fontSize: 24)),
                  title: const Text('PIN-kód a naplóhoz', style: TextStyle(fontWeight: FontWeight.w700)),
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
                    leading: Icon(Icons.pin_outlined, color: AppColors.primary),
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
                            secondary: Icon(Icons.fingerprint, color: AppColors.primary),
                            title: const Text('Feloldás ujjlenyomattal'),
                            value: store.useBiometrics,
                            onChanged: store.setUseBiometrics,
                          ),
                  ),
                ],
              ],
            ),
          ),
          const SectionTitle('Biztonsági mentés'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.download_outlined, color: AppColors.primary),
                  title: const Text('Mentés fájlba', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Minden adatod egy fájlban. Tedd el, vagy vidd át egy másik eszközre.'),
                  onTap: () => Backup.export(context, store),
                ),
                ListTile(
                  leading: const Icon(Icons.upload_outlined, color: AppColors.primary),
                  title: const Text('Visszatöltés fájlból', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Egy korábbi mentés visszaállítása.'),
                  onTap: () => Backup.restore(context, store),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              'A napló fotói nincsenek a mentésben, azok a telefonon maradnak.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
