import 'package:flutter/material.dart';

import '../account.dart';
import '../push.dart';
import '../store.dart';
import '../theme.dart';
import 'common.dart';

/// Böngészőben: „Tedd a kezdőképernyőre” (iPhone), utána „Kapcsold be az értesítéseket”.
class InstallAndPushCard extends StatefulWidget {
  const InstallAndPushCard({super.key});

  @override
  State<InstallAndPushCard> createState() => _InstallAndPushCardState();
}

class _InstallAndPushCardState extends State<InstallAndPushCard> {
  bool _busy = false;
  String? _message;

  Future<void> _enable() async {
    final uid = Account.instance.user?.uid;
    if (uid == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final ok = await Push.register(uid, ask: true);
      if (!mounted) return;
      setState(
        () => _message = ok
            ? null
            : Push.permission == 'denied'
            ? 'Le vannak tiltva. A telefon Beállítások → Értesítések menüjében engedélyezheted.'
            : 'Nem sikerült bekapcsolni. Próbáld újra.',
      );
    } catch (e) {
      if (mounted) setState(() => _message = 'Nem sikerült bekapcsolni: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (Push.needsInstall && !store.hintClosed('install')) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconTile(Icons.add_to_home_screen),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Tedd a kezdőképernyőre', style: Theme.of(context).textTheme.titleMedium)),
                  IconButton(
                    tooltip: 'Bezárás',
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => store.closeHint('install'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Így saját ikonnal, teljes képernyőn indul, és internet nélkül is megnyílik.',

                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 10),
              const _Step(n: 1, text: 'Koppints a Megosztás gombra (négyzet felfelé nyíllal).'),
              const _Step(n: 2, text: 'Válaszd: „Főképernyőhöz adás”.'),
              const _Step(n: 3, text: 'Nyisd meg a LIFEUP-ot az új ikonról.'),
            ],
          ),
        ),
      );
    }
    if (Push.configured && Push.supported && Push.permission == 'default' && !store.hintClosed('push')) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconTile(Icons.notifications_active_outlined),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Értesítések bekapcsolása', style: Theme.of(context).textTheme.titleMedium)),
                  IconButton(
                    tooltip: 'Bezárás',
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => store.closeHint('push'),
                  ),
                ],
              ),
              Text(
                'Meghívók, bökések és emlékeztetők akkor is, ha az app be van zárva.',
                style: TextStyle(color: AppColors.textMuted),
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_message!, style: TextStyle(color: Colors.red.shade400)),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 8),
                  child: FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                    onPressed: _busy ? null : _enable,
                    child: Text(_busy ? 'Bekapcsolás…' : 'Bekapcsolom'),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});

  final int n;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Text(
            '$n',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
