import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../account.dart';
import '../backup.dart';
import '../main.dart' show HomeShell;
import '../formatting.dart';
import '../friends.dart';
import '../notifications.dart';
import '../nudges.dart';
import '../push.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/profile_photo_button.dart';
import 'account_section.dart';
import 'challenges_screen.dart';
import 'google_calendar_screen.dart';
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
                  leading: ProfilePhotoButton(
                    name: store.myName,
                    photo: store.profilePhoto,
                    radius: 26,
                    onChanged: store.setProfilePhoto,
                  ),
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
                  trailing: StreamBuilder<int>(
                    stream: Nudges.instance.watchUnseenCount(),
                    builder: (context, snap) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if ((snap.data ?? 0) > 0) Pill('${snap.data} új', color: AppColors.danger),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
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
                  icon: Icons.calendar_month_outlined,
                  title: 'Google Naptár',
                  subtitle: store.googleConnected ? 'Összekapcsolva' : 'Hozd át az eseményeidet',
                  onTap: () => _push(context, const GoogleCalendarScreen()),
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
                    ThemeMode.light => store.whiteTheme ? 'Fehér' : 'Bézs',
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
        child: RadioGroup<String>(
          groupValue: switch (store.themeMode) {
            ThemeMode.light => store.whiteTheme ? 'white' : 'beige',
            ThemeMode.dark => 'dark',
            ThemeMode.system => 'system',
          },
          onChanged: (v) {
            switch (v) {
              case 'beige':
                store.setThemeMode(ThemeMode.light, white: false);
              case 'white':
                store.setThemeMode(ThemeMode.light, white: true);
              case 'dark':
                store.setThemeMode(ThemeMode.dark);
              case 'system':
                store.setThemeMode(ThemeMode.system);
            }
            Navigator.pop(context);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const RadioListTile(
                value: 'system',
                title: Text('A telefon beállítása szerint'),
                subtitle: Text('Világos vagy sötét, ahogy a telefonod'),
              ),
              RadioListTile(
                value: 'beige',
                title: const Text('Bézs'),
                subtitle: const Text('Krém és burgundi, a LIFEUP saját színei'),
                secondary: _ThemeSwatch(dark: false, white: false),
              ),
              RadioListTile(
                value: 'white',
                title: const Text('Fehér'),
                subtitle: const Text('Letisztult fehér, mint a legtöbb app'),
                secondary: _ThemeSwatch(dark: false, white: true),
              ),
              RadioListTile(
                value: 'dark',
                title: const Text('Sötét'),
                subtitle: const Text('Klasszikus sötét mód, kíméli a szemet este'),
                secondary: _ThemeSwatch(dark: true, white: false),
              ),
              if (store.themeMode == ThemeMode.system)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text(
                    'Világos napszakban a ${store.whiteTheme ? 'fehér' : 'bézs'} alapot használja.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 8),
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

/// Kis minta egy megjelenésről: háttér, rajta egy kártya és egy márkaszínű pötty.
class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.dark, required this.white});

  final bool dark;
  final bool white;

  @override
  Widget build(BuildContext context) {
    final border = AppColors.borderFor(dark, white: white);
    return Container(
      width: 44,
      height: 44,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: AppColors.backgroundFor(dark, white: white),
        borderRadius: BorderRadius.circular(Space.radiusSmall),
        border: Border.all(color: border),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardFor(dark, white: white),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: AppColors.primaryFor(dark, white: white),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
