import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../account.dart';
import '../backup.dart';
import '../main.dart' show HomeShell;
import '../formatting.dart';
import '../friends.dart';
import '../notifications.dart';
import '../push.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'account_section.dart';
import 'challenges_screen.dart';
import 'habits_screen.dart';
import 'nudge_screens.dart';
import 'privacy_screen.dart';

/// Profil: névjegy, célok és kihívások, beállítások, fiók.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _editName(BuildContext context) async {
    final store = StoreScope.of(context);
    final name = await showTextInputSheet(
      context,
      title: 'A neved',
      hint: store.myName.isEmpty ? 'Így látnak a barátaid' : store.myName,
    );
    if (name != null && name.trim().isNotEmpty) store.setMyName(name);
  }

  Future<void> _editBirthday(BuildContext context) async {
    final store = StoreScope.of(context);
    final current = store.birthday == null ? null : DateTime.tryParse(store.birthday!);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      initialEntryMode: DatePickerEntryMode.input,
      helpText: 'Születésnap',
    );
    if (picked != null) store.setBirthday(DateFormat('yyyy-MM-dd').format(picked));
  }

  void _push(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final user = Account.instance.user;
    final birthday = store.birthday == null ? null : DateTime.tryParse(store.birthday!);
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  leading: NameAvatar(store.myName.isEmpty ? '?' : store.myName, radius: 26),
                  title: Text(
                    store.myName.isEmpty ? 'Add meg a neved' : store.myName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  subtitle: Text(
                    [
                      user?.email ?? '',
                      if (Friends.instance.myCode != null) 'Kód: ${Friends.instance.myCode}',
                    ].where((s) => s.isNotEmpty).join(' · '),
                  ),
                  trailing: IconButton(
                    tooltip: 'Név szerkesztése',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editName(context),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.cake_outlined),
                  title: Text(
                    birthday == null ? 'Születésnap megadása' : DateFormat('yyyy. MMMM d.', 'hu').format(birthday),
                  ),
                  subtitle: Text(store.shareBirthday ? 'A barátaid látják (év nélkül)' : 'Csak te látod'),
                  onTap: () => _editBirthday(context),
                ),
              ],
            ),
          ),
          const SectionTitle('Fejlődés'),
          Card(
            child: Column(
              children: [
                SettingsTile(
                  icon: Icons.flag_outlined,
                  title: 'Céljaim',
                  subtitle: store.habits.isEmpty
                      ? 'Még nincs célod'
                      : '${store.habits.length} cél · ma ${store.habits.length - store.habitsLeftToday} kész',
                  onTap: () => _push(context, const HabitsScreen()),
                ),
                SettingsTile(
                  icon: Icons.emoji_events_outlined,
                  title: 'Kihívások',
                  subtitle: 'Közös célok a barátaiddal, ranglistával',
                  onTap: () => _push(context, const ChallengesScreen()),
                ),
                SettingsTile(
                  icon: Icons.waving_hand_outlined,
                  title: 'Kapott bökések',
                  onTap: () => _push(context, const NudgeInboxScreen()),
                ),
              ],
            ),
          ),
          const SectionTitle('Beállítások'),
          Card(
            child: Column(
              children: [
                SettingsTile(
                  icon: Icons.lock_outline,
                  title: 'Adatvédelem',
                  subtitle: 'Elérhetőség: ${store.shareAvailability.label.toLowerCase()}',
                  onTap: () => _push(context, const PrivacyScreen()),
                ),
                SettingsTile(
                  icon: Icons.notifications_none,
                  title: 'Értesítések',
                  onTap: () => _push(context, const NotificationSettingsScreen()),
                ),
                SettingsTile(
                  icon: Icons.dashboard_customize_outlined,
                  title: 'Főoldal testreszabása',
                  subtitle: 'Kártyák sorrendje, elrejtése',
                  onTap: () => _push(context, const HomeCardsScreen()),
                ),
                SettingsTile(
                  icon: Icons.palette_outlined,
                  title: 'Megjelenés',
                  subtitle: switch (store.themeMode) {
                    ThemeMode.light => 'Világos',
                    ThemeMode.dark => 'Sötét',
                    ThemeMode.system => 'A telefon beállítása szerint',
                  },
                  onTap: () => _showTheme(context),
                ),
                SettingsTile(
                  icon: Icons.download_outlined,
                  title: 'Adataim exportálása',
                  subtitle: 'Minden saját adat egy fájlban',
                  onTap: () => Backup.export(context, store),
                ),
                SettingsTile(
                  icon: Icons.upload_outlined,
                  title: 'Export visszatöltése',
                  onTap: () => Backup.restore(context, store),
                ),
                SettingsTile(
                  icon: Icons.school_outlined,
                  title: 'Bemutató újra',
                  subtitle: 'Végigvezet az app fő részein',
                  onTap: () => HomeShell.startTour(context),
                ),
              ],
            ),
          ),
          const AccountSection(),
        ],
      ),
    );
  }

  Future<void> _showTheme(BuildContext context) {
    final store = StoreScope.of(context);
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: RadioGroup<ThemeMode>(
          groupValue: store.themeMode,
          onChanged: (m) {
            if (m != null) store.setThemeMode(m);
            Navigator.pop(context);
          },
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile(value: ThemeMode.system, title: Text('A telefon beállítása szerint')),
              RadioListTile(value: ThemeMode.light, title: Text('Világos')),
              RadioListTile(value: ThemeMode.dark, title: Text('Sötét')),
              SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Értesítések: mire kérsz emlékeztetőt, és alapból mennyivel előtte.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Értesítések')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          if (!Notifications.supported) const _WebNotice(),
          const SectionTitle('Emlékeztetők'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Naptárbejegyzések'),
                  subtitle: const Text('Mindegyiknél külön állítható, mennyivel előtte.'),
                  value: store.eventReminders,
                  onChanged: (v) => store.setReminders(events: v),
                ),
                ListTile(
                  title: const Text('Új bejegyzésnél alapból'),
                  trailing: DropdownButton<int?>(
                    value: store.defaultReminderMin,
                    underline: const SizedBox.shrink(),
                    items: [for (final m in reminderOptions) DropdownMenuItem(value: m, child: Text(reminderLabel(m)))],
                    onChanged: (m) =>
                        m == null ? store.setReminders(clearDefault: true) : store.setReminders(defaultMin: m),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Feladatok'),
                  subtitle: const Text('A beosztott időpontban, vagy a határidő napján reggel 9-kor.'),
                  value: store.taskReminders,
                  onChanged: (v) => store.setReminders(tasks: v),
                ),
                SwitchListTile(
                  title: const Text('A barátaim születésnapja'),
                  subtitle: const Text('Aznap reggel, ha megosztják.'),
                  value: store.birthdayReminders,
                  onChanged: (v) => store.setReminders(birthdays: v),
                ),
                SwitchListTile(
                  title: const Text('Emlékek'),
                  subtitle: const Text('Ha egy közös program évfordulója van (pl. ma 1 éve volt).'),
                  value: store.memoryReminders,
                  onChanged: (v) => store.setReminders(memories: v),
                ),
              ],
            ),
          ),
          if (Notifications.supported) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final ok = await Notifications.requestPermission();
                if (ok) await Notifications.showTest();
              },
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Próba értesítés'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Böngészőben: mi működik az értesítésekből.
class _WebNotice extends StatelessWidget {
  const _WebNotice();

  @override
  Widget build(BuildContext context) {
    final text = !kIsWeb
        ? 'Ezen az eszközön az emlékeztetők nem érhetők el.'
        : !Push.configured
        ? 'Böngészőben most csak nyitott appnál látod a meghívókat és bökéseket. A beállított emlékeztetők '
              'Android telefonon működnek; bezárt appra küldött értesítéshez szerver kell, ami még nincs bekapcsolva.'
        : 'Böngészőben az értesítéseket a Főoldal „Értesítések bekapcsolása” kártyáján kapcsolhatod be.';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.info_outline),
        title: Text(text, style: TextStyle(color: AppColors.textMuted)),
      ),
    );
  }
}

/// A Főoldal kártyái: sorrend (húzással) és láthatóság.
class HomeCardsScreen extends StatelessWidget {
  const HomeCardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Főoldal')),
      body: ReorderableListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: SwitchListTile(
                secondary: const Icon(Icons.lightbulb_outline),
                title: const Text('Tippek'),
                subtitle: const Text('Néha egy rövid „Tudtad?” a Főoldalon (legfeljebb kétnaponta).'),
                value: store.tipsOn,
                onChanged: store.setTipsOn,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
              child: Text(
                'Húzd a kártyákat a kívánt sorrendbe, és kapcsold ki, amire nincs szükséged.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
        onReorderItem: store.moveCardTo,
        children: [
          for (final c in store.homeCards)
            Card(
              key: ValueKey(c),
              child: SwitchListTile(
                secondary: Icon(c.icon),
                title: Text(c.label),
                value: store.showsCard(c),
                onChanged: (v) => store.setCardVisible(c, v),
              ),
            ),
        ],
      ),
    );
  }
}
