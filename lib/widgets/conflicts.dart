import 'package:flutter/material.dart';

import '../formatting.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';

/// Egy ütközés kiírása, pl. „Fogorvos · ma 13:00–14:00”.
String conflictLine(Conflict c) {
  final day = formatDay(c.start, short: true);
  return '${c.title} · ${day == 'Ma' ? 'ma' : day} ${formatRange(c.start, c.end)}';
}

/// Figyelmeztetés a szerkesztőben, ha a választott időpontban már van valami.
class ConflictHint extends StatelessWidget {
  const ConflictHint({super.key, required this.conflicts});

  final List<Conflict> conflicts;

  @override
  Widget build(BuildContext context) {
    if (conflicts.isEmpty) return const SizedBox.shrink();
    final color = AppColors.category(EventCategory.important);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppColors.dark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(Space.radiusSmall),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ebben az időpontban már van programod',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
                ),
                const SizedBox(height: 2),
                for (final c in conflicts.take(3)) Text(conflictLine(c), style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                if (conflicts.length > 3) Text('és még ${conflicts.length - 3}', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mentés előtti kérdés ütközésnél. Igazat ad, ha mégis menteni szeretné.
Future<bool> confirmDespiteConflicts(BuildContext context, List<Conflict> conflicts) async {
  if (conflicts.isEmpty) return true;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.event_busy_outlined, color: AppColors.category(EventCategory.important)),
      title: const Text('Ebben az időpontban már van programod'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in conflicts.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(c.task ? Icons.task_alt : Icons.event_outlined, size: 18, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(child: Text(conflictLine(c))),
                ],
              ),
            ),
          if (conflicts.length > 5) Text('és még ${conflicts.length - 5}'),
          const SizedBox(height: 8),
          const Text('Biztosan hozzáadod így is?'),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Időpont módosítása')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Mégis hozzáadom')),
      ],
    ),
  );
  return ok == true;
}
