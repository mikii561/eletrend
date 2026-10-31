import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../account.dart';
import '../admin.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'admin_screen.dart';

/// Fiók a Beállításokban: ki van bejelentkezve, kijelentkezés, fiók törlése.
class AccountSection extends StatelessWidget {
  const AccountSection({super.key});

  Future<void> _logout(BuildContext context) async {
    final store = StoreScope.of(context);
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kijelentkezel?'),
        content: const Text(
          'Az adataid a fiókodban maradnak, erről az eszközről viszont lekerülnek. '
          'Bármikor visszajelentkezhetsz.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Mégse')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kijelentkezés')),
        ],
      ),
    );
    if (ok != true) return;
    final sync = Account.instance.sync;
    try {
      await sync?.push(); // ami még nem ment fel, az most
    } catch (_) {
      // Ha nincs internet, a legutóbbi szinkronizálás óta történt változások elvesznek;
      // erről a felhasználót nem tudjuk megkérdezni anélkül, hogy bent ragadna.
    }
    sync?.stop();
    Account.instance.sync = null;
    navigator.popUntil((r) => r.isFirst);
    await Account.instance.logout();
    await store.clearAll();
  }

  Future<void> _delete(BuildContext context) async {
    final store = StoreScope.of(context);
    final navigator = Navigator.of(context);
    final google = Account.instance.usesGoogle;
    final password = TextEditingController();
    String? error;
    var busy = false;
    final deleted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Fiók végleges törlése'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A fiókod és minden adatod (naptár, feladatok, célok, csoportok) végleg törlődik. '
                'Ezt nem lehet visszavonni. ${google ? 'A megerősítéshez jelentkezz be újra a Google-fiókoddal.' : 'A megerősítéshez add meg a jelszavad.'}',
              ),
              if (!google) const SizedBox(height: 12),
              if (!google)
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: InputDecoration(labelText: 'Jelszó', errorText: error),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.pop(context, false), child: const Text('Mégse')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade400),
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      try {
                        Account.instance.sync?.stop();
                        await Account.instance.deleteAccount(google ? null : password.text);
                        if (context.mounted) Navigator.pop(context, true);
                      } on AccountException catch (e) {
                        setState(() {
                          error = e.message;
                          busy = false;
                        });
                      }
                    },
              child: const Text('Törlés'),
            ),
          ],
        ),
      ),
    );
    password.dispose();
    if (deleted != true) {
      Account.instance.sync?.listen();
      return;
    }
    Account.instance.sync = null;
    navigator.popUntil((r) => r.isFirst);
    await store.clearAll();
  }

  Future<void> _feedback(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const FeedbackSheet(),
      );

  @override
  Widget build(BuildContext context) {
    final user = Account.instance.user;
    final store = StoreScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Fiók'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: NameAvatar(store.myName.isEmpty ? '?' : store.myName),
                title: Text(
                  store.myName.isEmpty ? (user?.displayName ?? 'Fiók') : store.myName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('${user?.email ?? ''}\nAz adataid a fiókodban vannak, minden eszközödön ugyanazok.'),
                isThreeLine: true,
              ),
              ListTile(
                leading: Icon(Icons.feedback_outlined, color: AppColors.primary),
                title: const Text('Hiba bejelentése / ötlet'),
                subtitle: const Text('Írd meg, mi nem működik, vagy mit látnál szívesen.'),
                onTap: () => _feedback(context),
              ),
              if (user != null)
                FutureBuilder<bool>(
                  future: Admin.instance.isAdmin(user.uid),
                  builder: (context, snap) => snap.data != true
                      ? const SizedBox.shrink()
                      : ListTile(
                          leading: Icon(Icons.admin_panel_settings_outlined, color: AppColors.accent),
                          title: const Text('Admin felület', style: TextStyle(fontWeight: FontWeight.w700)),
                          trailing: StreamBuilder<int>(
                            stream: Admin.instance.watchOpenCount(),
                            builder: (context, open) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if ((open.data ?? 0) > 0) Pill('${open.data} vár', color: AppColors.danger),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
                          onTap: () =>
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminScreen())),
                        ),
                ),
              ListTile(
                leading: Icon(Icons.logout, color: AppColors.primary),
                title: const Text('Kijelentkezés'),
                onTap: () => _logout(context),
              ),
              ListTile(
                leading: Icon(Icons.delete_forever_outlined, color: Colors.red.shade400),
                title: Text('Fiók törlése', style: TextStyle(color: Colors.red.shade400)),
                onTap: () => _delete(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// „Hiba bejelentése / ötlet”: szöveg és legfeljebb [Admin.maxScreenshots] képernyőkép.
class FeedbackSheet extends StatefulWidget {
  const FeedbackSheet({super.key, this.pick});

  /// Képek kiválasztása (tesztben kicserélhető); alapból a telefon/böngésző képválasztója.
  final Future<List<Uint8List>> Function(int limit)? pick;

  @override
  State<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<FeedbackSheet> {
  final _text = TextEditingController();
  final List<Uint8List> _images = [];
  bool _sending = false;
  bool _picking = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  static Future<List<Uint8List>> _pickFromDevice(int limit) async {
    final files = await ImagePicker().pickMultiImage(limit: limit);
    return [for (final f in files.take(limit)) await f.readAsBytes()];
  }

  Future<void> _addImages() async {
    final left = Admin.maxScreenshots - _images.length;
    if (left <= 0) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final picked = await (widget.pick ?? _pickFromDevice)(left);
      var failed = 0;
      for (final bytes in picked.take(left)) {
        try {
          _images.add(Admin.prepareScreenshot(bytes));
        } on FormatException {
          failed++;
        }
      }
      if (failed > 0) _error = failed == 1 ? 'Egy képet nem tudtam megnyitni.' : '$failed képet nem tudtam megnyitni.';
    } catch (e) {
      _error = 'Nem sikerült megnyitni a képeket.';
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _send() async {
    final message = _text.text.trim();
    if (message.isEmpty) {
      setState(() => _error = 'Írd le pár szóban, mi történt.');
      return;
    }
    final user = Account.instance.user;
    if (user == null) return;
    final store = StoreScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await Admin.instance.sendFeedback(uid: user.uid, name: store.myName, email: user.email ?? '', text: message, images: _images);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Köszönjük! Megkaptuk. 💜')));
    } catch (e) {
      if (mounted) setState(() => _error = 'Nem sikerült elküldeni. Van internet?');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Hiba bejelentése / ötlet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              autofocus: true,
              minLines: 4,
              maxLines: 8,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Mi történt? Mit csináltál előtte? Vagy mi hiányzik?'),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 4),
            Text(
              'Egy képernyőkép sokat segít: azon látjuk, mi jelent meg.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _images.length; i++)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(Space.radiusSmall),
                        child: Image.memory(_images[i], width: 80, height: 80, fit: BoxFit.cover),
                      ),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => setState(() => _images.removeAt(i)),
                            child: const Padding(
                              padding: EdgeInsets.all(3),
                              child: Icon(Icons.close, size: 14, color: Colors.white, semanticLabel: 'Kép eltávolítása'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                if (_images.length < Admin.maxScreenshots)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 80)),
                    onPressed: _picking || _sending ? null : _addImages,
                    icon: _picking
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(_images.isEmpty ? 'Képernyőkép csatolása' : 'Még egy (${_images.length}/${Admin.maxScreenshots})'),
                  ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: AppColors.danger, fontSize: 13)),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _sending || _picking ? null : _send,
              child: Text(_sending ? 'Küldés…' : 'Küldés'),
            ),
          ],
        ),
      ),
    );
  }
}
