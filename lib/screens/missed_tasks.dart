import 'package:flutter/material.dart';

import '../formatting.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';

/// Főoldali kártya: „Van elmaradt teendőd. Szeretnéd folytatni?” Igen → egyenként átteheted másik napra
/// (vagy késznek jelölheted, törölheted); Nem → az elmaradtak törlődnek (megerősítés után).
class MissedTasksBanner extends StatelessWidget {
  const MissedTasksBanner({super.key, required this.store, required this.now});

  final AppStore store;
  final DateTime now;

  static String countText(int n) => n == 1 ? 'Van egy elmaradt teendőd' : 'Van $n elmaradt teendőd';

  @override
  Widget build(BuildContext context) {
    final missed = store.missedTasks(now: now);
    if (missed.isEmpty) return const SizedBox.shrink();
    return Card(
      color: AppColors.danger.withValues(alpha: AppColors.dark ? 0.14 : 0.07),
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history_toggle_off, color: AppColors.danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    countText(missed.length),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Szeretnéd folytatni?', style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: () => showMissedTasks(context),
                  child: const Text('Igen'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: () => _discard(context, missed),
                  child: const Text('Nem, töröld'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _discard(BuildContext context, List<TaskItem> missed) async {
    final ok = await confirm(
      context,
      title: missed.length == 1 ? 'Töröljem ezt a teendőt?' : 'Töröljem az elmaradt teendőket?',
      text: missed.length == 1 ? missed.first.title : '${missed.length} teendő törlődik, nem lehet visszahozni.',
      action: 'Törlés',
      danger: true,
    );
    if (!ok) return;
    for (final t in missed) {
      store.removeTask(t);
    }
  }
}

/// Az elmaradt teendők listája: mindegyiknél egy koppintással új napot adhatsz (Ma, Holnap, Másik nap),
/// késznek jelölheted vagy törölheted. Ha mind elintéződött, a lap magától bezárul.
Future<void> showMissedTasks(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => const _MissedSheet(),
);

class _MissedSheet extends StatelessWidget {
  const _MissedSheet();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final missed = store.missedTasks();
    if (missed.isEmpty) {
      // Minden elintézve: bezárjuk (a következő képkockában, építés közben nem szabad).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
    }
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text('Elmaradt teendők', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Mikorra tegyük át őket?', style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 8),
            for (final t in missed) _MissedTile(task: t, store: store),
          ],
        ),
      ),
    );
  }
}

class _MissedTile extends StatelessWidget {
  const _MissedTile({required this.task, required this.store});

  final TaskItem task;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final day = task.day!;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(task.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                IconButton(
                  tooltip: 'Kész',
                  icon: Icon(Icons.check_circle_outline, color: AppColors.status(AvailabilityStatus.available)),
                  onPressed: () => store.toggleTask(task),
                ),
                IconButton(
                  tooltip: 'Törlés',
                  icon: Icon(Icons.delete_outline, color: AppColors.danger),
                  onPressed: () => store.removeTask(task),
                ),
              ],
            ),
            Text(
              'Eredetileg: ${formatDay(day, now: now)}',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ActionChip(label: const Text('Ma'), onPressed: () => store.moveTask(task, now)),
                ActionChip(
                  label: const Text('Holnap'),
                  onPressed: () => store.moveTask(task, DateTime(now.year, now.month, now.day + 1)),
                ),
                ActionChip(
                  avatar: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: const Text('Másik nap'),
                  onPressed: () async {
                    final picked = await pickDay(
                      context,
                      initial: DateTime(now.year, now.month, now.day + 1),
                      first: DateTime(now.year, now.month, now.day),
                      last: DateTime(now.year + 5, 12, 31),
                      title: 'Melyik napra tegyük át?',
                    );
                    if (picked != null) store.moveTask(task, picked);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
