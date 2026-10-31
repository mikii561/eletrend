import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';
import 'privacy_screen.dart';

/// Az állapotom beállítása (a nap végéig), vagy vissza az automatikusra.
Future<void> showStatusSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final store = StoreScope.of(context);
      final manual = store.statusIsManual ? store.manualStatus : null;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text('Az állapotod', style: Theme.of(context).textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                store.shareAvailability == AvailabilityShare.nobody
                    ? 'Most senki sem látja: az elérhetőséged megosztása ki van kapcsolva.'
                    : 'A barátaid ezt látják ma éjfélig. Utána újra a naptárad alapján: foglalt, ha épp tart valami.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
            RadioGroup<AvailabilityStatus?>(
              groupValue: manual,
              onChanged: (s) {
                store.setManualStatus(s);
                Navigator.pop(context);
              },
              child: Column(
                children: [
                  const RadioListTile<AvailabilityStatus?>(
                    value: null,
                    title: Text('Automatikus'),
                    subtitle: Text('A naptáram alapján'),
                  ),
                  for (final s in AvailabilityStatus.values)
                    RadioListTile<AvailabilityStatus?>(
                      value: s,
                      secondary: Icon(statusIcon(s), color: AppColors.status(s)),
                      title: Text(s.label),
                    ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () {
                final navigator = Navigator.of(context)..pop();
                navigator.push(MaterialPageRoute(builder: (_) => const PrivacyScreen()));
              },
              icon: const Icon(Icons.lock_outline),
              label: const Text('Kik látják? Adatvédelem'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
