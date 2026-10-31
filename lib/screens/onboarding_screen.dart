import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../account.dart';
import '../availability.dart';
import '../notifications.dart';
import '../store.dart';
import '../theme.dart';

/// Bevezető az első indításkor: üdvözlés, profil, mire használnád, mikor érsz rá, értesítések.
/// A fiók ekkor már megvan (a bejelentkezés előtte jön). Az opcionális lépések kihagyhatók.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

/// Mire használnád: melyik Főoldal-kártyák látszódjanak.
enum _Use {
  goals('Célok és szokások', Icons.flag_outlined, {HomeCard.goals}),
  friends('Barátok és közös programok', Icons.people_alt_outlined, {HomeCard.friends, HomeCard.birthdays}),
  challenges('Kihívások a barátaimmal', Icons.emoji_events_outlined, {HomeCard.challenges});

  const _Use(this.label, this.icon, this.cards);

  final String label;
  final IconData icon;
  final Set<HomeCard> cards;
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  final _name = TextEditingController();
  bool _nameFilled = false;
  DateTime? _birthday;
  final Set<_Use> _uses = {..._Use.values};
  final Set<FreeWindow> _windows = {};
  bool _share = false;
  String? _nameError;

  /// Az értesítési lépés csak ott van, ahol helyi értesítés működik (Android).
  int get _steps => Notifications.supported ? 5 : 4;

  String _initialName() {
    final store = StoreScope.of(context);
    if (store.myName.isNotEmpty) return store.myName;
    return Account.instance.user?.displayName ?? '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A név előtöltése egyszer (a store itt már elérhető, az initState-ben még nem).
    if (_nameFilled) return;
    _nameFilled = true;
    _name.text = _initialName();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 1 && _name.text.trim().isEmpty) {
      setState(() => _nameError = 'Hogy szólíthatunk? (A barátaid is így látnak.)');
      return;
    }
    if (_step + 1 >= _steps) {
      _finish();
      return;
    }
    setState(() => _step++);
  }

  void _finish() {
    final hidden = {
      for (final u in _Use.values)
        if (!_uses.contains(u)) ...u.cards,
    };
    StoreScope.of(context).finishOnboarding(
      name: _name.text,
      birthday: _birthday == null ? null : DateFormat('yyyy-MM-dd').format(_birthday!),
      windows: _windows.toList(),
      share: _share ? AvailabilityShare.friends : AvailabilityShare.nobody,
      hidden: hidden,
    );
  }

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      initialEntryMode: DatePickerEntryMode.input,
      helpText: 'Születésnap',
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final optional = _step >= 2;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  for (var i = 0; i < _steps; i++)
                    Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: i <= _step ? AppColors.primary : AppColors.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                children: [
                  ...switch (_step) {
                    0 => _welcome(theme),
                    1 => _profile(theme),
                    2 => _usage(theme),
                    3 => _availability(theme),
                    _ => _notifications(theme),
                  },
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Row(
                children: [
                  if (_step > 0)
                    IconButton(
                      tooltip: 'Vissza',
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => setState(() => _step--),
                    ),
                  const Spacer(),
                  if (optional && _step + 1 < _steps)
                    TextButton(onPressed: () => setState(() => _step++), child: const Text('Kihagyom')),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(112, 48)),
                    onPressed: _next,
                    child: Text(_step == 0 ? 'Kezdjük' : (_step + 1 >= _steps ? 'Kész' : 'Tovább')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _title(ThemeData theme, String title, String text) => [
    Text(title, style: theme.textTheme.headlineMedium),
    const SizedBox(height: 8),
    Text(text, style: TextStyle(color: AppColors.textMuted, fontSize: 16, height: 1.4)),
    const SizedBox(height: 24),
  ];

  List<Widget> _welcome(ThemeData theme) => [
    Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(gradient: AppColors.headerGradient, borderRadius: BorderRadius.circular(20)),
      child: Icon(Icons.check_rounded, color: AppColors.onPrimaryFor(false), size: 40),
    ),
    const SizedBox(height: 24),
    ..._title(theme, 'Üdv a LIFEUP-ban!', 'Az életed. Az embereid. Az időd.'),
    for (final (icon, title, text) in [
      (Icons.calendar_month_outlined, 'Naptár és teendők', 'A napod egy helyen, emlékeztetőkkel.'),
      (Icons.people_alt_outlined, 'Barátok', 'Lásd, ki mikor ér rá, és szervezz közös programot pár koppintással.'),
      (Icons.flag_outlined, 'Célok', 'Kövesd a szokásaidat, egyedül vagy a barátaiddal.'),
    ])
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  Text(text, style: TextStyle(color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    Text(
      'Barátok nélkül is teljes értékű naptár: a közösségi rész csak kiegészítés.',
      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
    ),
  ];

  List<Widget> _profile(ThemeData theme) => [
    ..._title(
      theme,
      'Mutatkozz be',
      'Így látnak a barátaid. A születésnapod nem kötelező, és csak akkor látják, ha engeded.',
    ),
    TextField(
      controller: _name,
      maxLength: 40,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: 'Neved',
        prefixIcon: const Icon(Icons.person_outline),
        errorText: _nameError,
      ),
      onChanged: (_) {
        if (_nameError != null) setState(() => _nameError = null);
      },
    ),
    const SizedBox(height: 8),
    Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.cake_outlined),
        title: Text(
          _birthday == null ? 'Születésnap (nem kötelező)' : DateFormat('yyyy. MMMM d.', 'hu').format(_birthday!),
        ),
        trailing: _birthday == null
            ? const Icon(Icons.chevron_right)
            : IconButton(
                tooltip: 'Törlés',
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _birthday = null),
              ),
        onTap: _pickBirthday,
      ),
    ),
  ];

  List<Widget> _usage(ThemeData theme) => [
    ..._title(
      theme,
      'Mire használnád?',
      'A naptár és a teendők mindig megvannak. A többit később a Profilban is ki-be kapcsolhatod.',
    ),
    for (final u in _Use.values)
      Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: CheckboxListTile(
          secondary: Icon(u.icon),
          title: Text(u.label),
          value: _uses.contains(u),
          onChanged: (on) => setState(() => on == true ? _uses.add(u) : _uses.remove(u)),
        ),
      ),
  ];

  List<Widget> _availability(ThemeData theme) => [
    ..._title(
      theme,
      'Mikor szoktál ráérni?',
      'Ezzel segítünk közös időpontot találni a barátaiddal. A bejegyzéseid részleteit senki sem látja, csak hogy foglalt vagy-e.',
    ),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in freeWindowPresets)
          FilterChip(
            label: Text(p.label),
            selected: _windows.contains(p.window),
            onSelected: (on) => setState(() => on ? _windows.add(p.window) : _windows.remove(p.window)),
          ),
      ],
    ),
    const SizedBox(height: 24),
    Card(
      margin: EdgeInsets.zero,
      child: SwitchListTile(
        title: const Text('Megosztom a barátaimmal, mikor érek rá'),
        subtitle: const Text('Csak szabad/foglalt. Bármikor kikapcsolhatod, vagy szűkítheted csoportokra.'),
        value: _share,
        onChanged: (v) => setState(() => _share = v),
      ),
    ),
  ];

  List<Widget> _notifications(ThemeData theme) => [
    ..._title(
      theme,
      'Emlékeztetők',
      'Szólunk a bejegyzéseid előtt, a feladataid határidején, és a barátaid születésnapján. '
          'Ehhez a telefon engedélyt kér; később a Profil → Értesítések alatt állíthatod.',
    ),
    FilledButton.tonalIcon(
      onPressed: () async {
        await Notifications.requestPermission();
        _finish();
      },
      icon: const Icon(Icons.notifications_active_outlined),
      label: const Text('Engedélyezem'),
    ),
  ];
}
