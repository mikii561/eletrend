import 'package:flutter/material.dart';

import '../notifications.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Az értesítések le vannak tiltva. A telefon Beállítások → Alkalmazások → Életrend menüjében engedélyezheted.'),
      ));
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
                  subtitle: const Text('Ha még van kipipálatlan szokásod, vagy nem írtál naplót. Ha mindennel kész vagy, nem zavar.'),
                  value: store.dailyReminder,
                  onChanged: (on) => on
                      ? _enable(context, () => store.setReminders(daily: true))
                      : store.setReminders(daily: false),
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
              onChanged: (on) => on
                  ? _enable(context, () => store.setReminders(events: true))
                  : store.setReminders(events: false),
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
        ],
      ),
    );
  }
}
