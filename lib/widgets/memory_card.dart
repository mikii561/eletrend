import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../screens/journal_screen.dart';
import '../stats.dart';
import '../store.dart';
import '../theme.dart';
import 'tag_icon.dart';

/// „Egy éve ezen a napon”: egy régi bejegyzés felidézése a Ma képernyőn.
class MemoryCard extends StatelessWidget {
  const MemoryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    // Zárolt naplónál nem mutatunk belőle semmit.
    if (!store.journalVisible) return const SizedBox.shrink();
    final memory = memoryFor(store, DateTime.now());
    if (memory == null) return const SizedBox.shrink();
    final e = memory.entry;
    final text = [e.gratitude, e.answer, e.note].firstWhere((t) => t.isNotEmpty, orElse: () => '');
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        color: AppColors.accent.withValues(alpha: 0.12),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JournalEditor(date: e.date, existing: e))),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                EntryFace(e, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📸 ${memory.label}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(DateFormat('yyyy. MMMM d.', 'hu').format(e.date), style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      if (text.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
