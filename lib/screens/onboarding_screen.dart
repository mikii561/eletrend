import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text;

import '../l10n/text.dart';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../account.dart';
import '../l10n/l10n.dart';
import '../friends.dart';
import '../notifications.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/pickers.dart';
import '../widgets/motion.dart';
import '../widgets/profile_photo_button.dart';

/// Az első belépés: üdvözlés → első lépések (kihagyható) → születésnap → barátok → profilkép és név →
/// „kész is vagyunk” → a bemutató. A fiók ekkor már megvan (a bejelentkezés előtte jön).
/// Csak a név kötelező, és csak ha végigmész a lépéseken; minden más később is megadható a Profilban.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Page { welcome, language, intro, birthday, friends, profile, done }

class _OnboardingScreenState extends State<OnboardingScreen> {
  _Page _page = _Page.welcome;
  final _name = TextEditingController();
  final _friendCode = TextEditingController();
  bool _prefilled = false;
  DateTime? _birthday;
  String _photo = '';
  String? _nameError;
  String? _friendMessage;
  bool _friendOk = false;
  bool _friendBusy = false;
  bool _notificationsAsked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Előtöltés egyszer (a store itt már elérhető, az initState-ben még nem): ha egy korábbi, megszakadt
    // indításnál már megadtál valamit, az megmarad.
    if (_prefilled) return;
    _prefilled = true;
    final store = StoreScope.of(context);
    _name.text = store.myName.isNotEmpty ? store.myName : (Account.instance.user?.displayName ?? '');
    _photo = store.profilePhoto;
    _birthday = store.birthday == null ? null : DateTime.tryParse(store.birthday!);
  }

  @override
  void dispose() {
    _name.dispose();
    _friendCode.dispose();
    super.dispose();
  }

  /// Egy név a fiók adataiból, ha a felhasználó kihagyta a lépéseket.
  String _fallbackName() {
    final user = Account.instance.user;
    final name = user?.displayName?.trim() ?? '';
    if (name.isNotEmpty) return name;
    final email = user?.email ?? '';
    return email.contains('@') ? email.split('@').first : '';
  }

  void _go(_Page page) => setState(() => _page = page);

  void _next() {
    switch (_page) {
      case _Page.welcome:
        _go(_Page.language);
      case _Page.language:
        _go(_Page.intro);
      case _Page.intro:
        _go(_Page.birthday);
      case _Page.birthday:
        _go(_Page.friends);
      case _Page.friends:
        _go(_Page.profile);
      case _Page.profile:
        _saveProfile();
      case _Page.done:
        _finish();
    }
  }

  void _back() {
    switch (_page) {
      case _Page.language:
        _go(_Page.welcome);
      case _Page.intro:
        _go(_Page.language);
      case _Page.birthday:
        _go(_Page.intro);
      case _Page.friends:
        _go(_Page.birthday);
      case _Page.profile:
        _go(_Page.friends);
      case _Page.welcome || _Page.done:
        break;
    }
  }

  /// „Beállítom később”: semmit sem kérdezünk, a Profilban bármikor megadható.
  void _skipAll() => _go(_Page.done);

  /// A név, a profilkép és a születésnap mentése; utána a „kész” oldal jön.
  void _saveProfile() {
    if (_name.text.trim().isEmpty) {
      setState(() => _nameError = tr('Hogy szólíthatunk? (A barátaid is így látnak.)'));
      return;
    }
    final store = StoreScope.of(context);
    store
      ..setMyName(_name.text)
      ..setProfilePhoto(_photo)
      ..setBirthday(_birthday == null ? null : DateFormat('yyyy-MM-dd').format(_birthday!));
    _go(_Page.done);
  }

  /// Vége: innentől a Főoldal jön, és magától indul a bemutató.
  void _finish() {
    final store = StoreScope.of(context);
    store.finishOnboarding(name: store.myName.isEmpty ? _fallbackName() : null);
  }

  Future<void> _pickBirthday() async {
    final picked = await pickBirthday(context, initial: _birthday);
    if (picked != null) setState(() => _birthday = picked);
  }

  Future<void> _addFriend() async {
    if (_friendCode.text.trim().isEmpty) return;
    setState(() {
      _friendBusy = true;
      _friendMessage = null;
    });
    try {
      await Friends.instance.addByCode(_friendCode.text);
      if (!mounted) return;
      setState(() {
        _friendOk = true;
        _friendMessage = tr('Elküldtük a jelölést. Ha elfogadja, barátok lesztek. 🎉');
        _friendCode.clear();
      });
    } on FriendException catch (e) {
      if (mounted) {
        setState(() {
          _friendOk = false;
          _friendMessage = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _friendOk = false;
          _friendMessage = tr('Nem sikerült. Van internet?');
        });
      }
    } finally {
      if (mounted) setState(() => _friendBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final index = _Page.values.indexOf(_page);
    final optional = _page == _Page.birthday || _page == _Page.friends;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  for (var i = 0; i < _Page.values.length; i++)
                    Expanded(
                      child: AnimatedContainer(
                        duration: Motion.of(context, Motion.medium),
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: i <= index ? AppColors.primary : AppColors.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: Motion.of(context, Motion.medium),
                switchInCurve: Motion.curve,
                child: ListView(
                  key: ValueKey(_page),
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  children: switch (_page) {
                    _Page.welcome => _welcome(theme),
                    _Page.language => _languagePage(theme),
                    _Page.intro => _intro(theme),
                    _Page.birthday => _birthdayPage(theme),
                    _Page.friends => _friendsPage(theme),
                    _Page.profile => _profilePage(theme),
                    _Page.done => _done(theme),
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Row(
                children: [
                  if (_page != _Page.welcome && _page != _Page.done)
                    IconButton(tooltip: 'Vissza', icon: const Icon(Icons.arrow_back), onPressed: _back),
                  const Spacer(),
                  if (_page == _Page.intro)
                    Flexible(
                      child: TextButton(
                        onPressed: _skipAll,
                        child: const Text('Beállítom később', maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  if (optional) TextButton(onPressed: _next, child: const Text('Kihagyom')),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(112, 48)),
                    onPressed: _next,
                    child: const Text('Tovább'),
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

  Widget _logo() => Container(
    width: 72,
    height: 72,
    decoration: BoxDecoration(gradient: AppColors.headerGradient, borderRadius: BorderRadius.circular(20)),
    child: Icon(Icons.check_rounded, color: Colors.white, size: 40),
  );

  Widget _point(ThemeData theme, IconData icon, String title, String text) => Padding(
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
  );

  List<Widget> _welcome(ThemeData theme) => [
    _logo(),
    const SizedBox(height: 24),
    ..._title(theme, tr('Üdvözlünk a LIFEUP alkalmazásban!'), tr('Az életed. Az embereid. Az időd.')),
    _point(theme, Icons.calendar_month_outlined, tr('Naptár és teendők'), tr('A napod egy helyen, emlékeztetőkkel.')),
    _point(
      theme,
      Icons.people_alt_outlined,
      tr('Barátok'),
      tr('Lásd, ki mikor ér rá, és szervezz közös programot pár koppintással.'),
    ),
    _point(theme, Icons.flag_outlined, tr('Célok'), tr('Kövesd a szokásaidat, egyedül vagy a barátaiddal.')),
    Text(
      'Barátok nélkül is teljes értékű naptár: a közösségi rész csak kiegészítés.',
      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
    ),
  ];

  /// Nyelv: rögtön az üdvözlés után, hogy a többi lépés már a választott nyelven jöjjön.
  List<Widget> _languagePage(ThemeData theme) {
    final store = StoreScope.of(context);
    return [
      // Kétnyelvű, mert itt még nem tudjuk, melyiket érti jobban.
      Text('Choose your language', style: theme.textTheme.headlineMedium),
      const SizedBox(height: 4),
      Text('Válaszd ki a nyelvet', style: theme.textTheme.titleMedium?.copyWith(color: AppColors.textMuted)),
      const SizedBox(height: 12),
      const Text('You can change it any time in Profile → Language.', style: TextStyle(fontSize: 14)),
      const SizedBox(height: 24),
      for (final l in AppLanguage.values)
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: store.language == l ? AppColors.primary : AppColors.divider,
              width: store.language == l ? 2 : 1,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Text(l.flag, style: const TextStyle(fontSize: 30)),
            title: Text(l.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            trailing: store.language == l ? Icon(Icons.check_circle, color: AppColors.primary) : null,
            onTap: () => store.setLanguage(l),
          ),
        ),
    ];
  }

  List<Widget> _intro(ThemeData theme) => [
    ..._title(
      theme,
      tr('Első lépések'),
      tr(
        'Pár gyors kérdés, hogy a barátaid felismerjenek és minden a helyére kerüljön. Egy perc az egész, és szinte minden kihagyható.',
      ),
    ),
    _point(
      theme,
      Icons.cake_outlined,
      tr('Születésnap'),
      tr('Nem kötelező, és csak akkor látják a barátaid, ha engeded.'),
    ),
    _point(theme, Icons.person_add_alt_outlined, tr('Barátok'), tr('Ha egy barátod hívott meg, add meg a kódját.')),
    _point(theme, Icons.account_circle_outlined, tr('Profilkép és név'), tr('Így látnak a barátaid.')),
    Text(
      'Ha most nem érsz rá, válaszd a „Beállítom később” gombot: a Profilban bármikor megadhatod.',
      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
    ),
  ];

  List<Widget> _birthdayPage(ThemeData theme) => [
    ..._title(
      theme,
      tr('Mikor van a születésnapod?'),
      tr('A barátaid ezt látják meg a naptárukban, ha engeded (az évszám nélkül). Nem kötelező.'),
    ),
    Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.cake_outlined),
        title: Text(
          _birthday == null ? tr('Születésnap megadása') : DateFormat(tr('yyyy. MMMM d.'), L10n.code).format(_birthday!),
        ),
        trailing: _birthday == null
            ? const Icon(Icons.chevron_right)
            : IconButton(
                tooltip: tr('Törlés'),
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _birthday = null),
              ),
        onTap: _pickBirthday,
      ),
    ),
  ];

  List<Widget> _friendsPage(ThemeData theme) {
    final invitedByLink = kIsWeb && Uri.base.queryParameters['e'] != null;
    final code = Friends.instance.myCode;
    return [
      ..._title(
        theme,
        tr('Barátok felvétele'),
        invitedByLink
            ? tr('Egy barátod meghívott egy programra. Ha megadod a barátkódját, barátok is lehettek. Nem kötelező.')
            : tr('Ha egy barátod hívott meg, írd be a barátkódját, így egyből barátok lehettek. Nem kötelező.'),
      ),
      if (!Friends.instance.ready)
        Text(
          'A barátokhoz internet kell. Később a Barátok fülön is hozzáadhatod őket.',
          style: TextStyle(color: AppColors.textMuted),
        )
      else ...[
        TextField(
          controller: _friendCode,
          maxLength: 8,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: tr('Barátod kódja'),
            hintText: 'pl. AQX2VA',
            prefixIcon: Icon(Icons.person_add_alt_outlined),
            counterText: '',
          ),
          onSubmitted: (_) => _addFriend(),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: _friendBusy ? null : _addFriend,
          child: Text(_friendBusy ? tr('Küldés…') : tr('Jelölés küldése')),
        ),
        if (_friendMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _friendMessage!,
              style: TextStyle(color: _friendOk ? AppColors.status(AvailabilityStatus.available) : AppColors.danger),
            ),
          ),
        if (code != null) ...[
          const SizedBox(height: 24),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.qr_code_2_outlined),
              title: const Text('A te barátkódod'),
              subtitle: Text(code, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2)),
              trailing: IconButton(
                tooltip: tr('Másolás'),
                icon: const Icon(Icons.copy_outlined),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(ClipboardData(text: code));
                  messenger.showSnackBar(const SnackBar(content: Text('Kimásoltam a kódod.')));
                },
              ),
            ),
          ),
        ],
      ],
    ];
  }

  List<Widget> _profilePage(ThemeData theme) => [
    ..._title(
      theme,
      tr('Profilkép és név'),
      tr('Így látnak a barátaid. A képet kamerával vagy a galériából is megadhatod.'),
    ),
    Center(
      child: ProfilePhotoButton(
        name: _name.text,
        photo: _photo,
        radius: 56,
        onChanged: (v) => setState(() => _photo = v),
      ),
    ),
    const SizedBox(height: 24),
    TextField(
      controller: _name,
      maxLength: 40,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: 'Neved',
        prefixIcon: const Icon(Icons.person_outline),
        errorText: _nameError,
      ),
      onChanged: (_) => setState(() => _nameError = null),
    ),
  ];

  List<Widget> _done(ThemeData theme) => [
    Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(gradient: AppColors.headerGradient, borderRadius: BorderRadius.circular(20)),
      child: const Icon(Icons.celebration_outlined, color: Colors.white, size: 38),
    ),
    const SizedBox(height: 24),
    ..._title(
      theme,
      tr('Kész is vagyunk!'),
      tr('Mindent elmentettünk. A következő lépésben megmutatjuk, mit hol találsz az appban.'),
    ),
    if (Notifications.supported)
      Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(_notificationsAsked ? Icons.notifications_active : Icons.notifications_active_outlined),
          title: const Text('Emlékeztetők'),
          subtitle: Text(
            _notificationsAsked
                ? tr('Köszönjük! A Profil → Értesítések alatt bármikor átállíthatod.')
                : tr('Szólunk a bejegyzéseid előtt és a barátaid születésnapján. A telefon engedélyt kér.'),
          ),
          trailing: _notificationsAsked
              ? null
              : TextButton(
                  onPressed: () async {
                    await Notifications.requestPermission();
                    if (mounted) setState(() => _notificationsAsked = true);
                  },
                  child: const Text('Engedélyezem'),
                ),
        ),
      ),
  ];
}
