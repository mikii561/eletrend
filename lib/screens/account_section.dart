import 'package:flutter/material.dart';

import '../account.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

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
        content: const Text('Az adataid a fiókodban maradnak, erről az eszközről viszont lekerülnek. '
            'Bármikor visszajelentkezhetsz.'),
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
              const Text('A fiókod és minden adatod (napló, szokások, programok) végleg törlődik. '
                  'Ezt nem lehet visszavonni. A megerősítéshez add meg a jelszavad.'),
              const SizedBox(height: 12),
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
                        await Account.instance.deleteAccount(password.text);
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
                title: Text(store.myName.isEmpty ? (user?.displayName ?? 'Fiók') : store.myName,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${user?.email ?? ''}\nAz adataid a fiókodban vannak, minden eszközödön ugyanazok.'),
                isThreeLine: true,
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.primary),
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
