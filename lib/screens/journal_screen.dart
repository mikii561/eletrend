import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'stats_screen.dart';
import 'today_screen.dart' show MoodButton;

/// Hangulat- és hálanapló: a hét hangulata és a korábbi bejegyzések.
class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final todayEntry = store.entryFor(now);

    void openEditor(DateTime date, JournalEntry? existing) => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => JournalEditor(date: date, existing: existing)),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Napló'),
        actions: [
          IconButton.filledTonal(
            tooltip: 'Statisztika',
            icon: const Icon(Icons.insights),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StatsScreen())),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openEditor(now, todayEntry),
        icon: const Icon(Icons.edit_outlined),
        label: Text(todayEntry == null ? 'Mai bejegyzés' : 'Mai szerkesztése', style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          _MoodWeek(store: store),
          if (store.journal.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: EmptyState(emoji: '📔', text: 'Még nincs bejegyzésed.\nÍrd le, milyen napod volt és miért vagy hálás!'),
            )
          else ...[
            const SectionTitle('Bejegyzések'),
            for (final j in store.journal) _EntryCard(entry: j, onTap: () => openEditor(j.date, j)),
          ],
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.onTap});

  final JournalEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final j = entry;
    final color = AppColors.moods[j.mood - 1];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(moodEmojis[j.mood - 1], style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 8),
                          Text(DateFormat('MMMM d., EEEE', 'hu').format(j.date),
                              style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                      if (j.gratitude.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('🙏 ${j.gratitude}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                      if (j.note.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(j.note, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Az elmúlt 7 nap hangulata oszlopokként.
class _MoodWeek extends StatelessWidget {
  const _MoodWeek({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: AppColors.headerGradient, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Az elmúlt hét', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final d in days)
                  Builder(builder: (context) {
                    final e = store.entryFor(d);
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(e == null ? '' : moodEmojis[e.mood - 1], style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 22,
                          height: e == null ? 6 : 10.0 + e.mood * 10,
                          decoration: BoxDecoration(
                            color: e == null ? Colors.white24 : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(DateFormat.E('hu').format(d),
                            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Egy nap bejegyzésének megírása vagy szerkesztése.
class JournalEditor extends StatefulWidget {
  const JournalEditor({super.key, required this.date, this.existing});

  final DateTime date;
  final JournalEntry? existing;

  @override
  State<JournalEditor> createState() => _JournalEditorState();
}

class _JournalEditorState extends State<JournalEditor> {
  late int _mood = widget.existing?.mood ?? 3;
  late final _gratitude = TextEditingController(text: widget.existing?.gratitude);
  late final _note = TextEditingController(text: widget.existing?.note);

  void _save() {
    StoreScope.of(context).saveEntry(JournalEntry(
      id: widget.existing?.id ?? newId(),
      date: widget.date,
      mood: _mood,
      gratitude: _gratitude.text.trim(),
      note: _note.text.trim(),
    ));
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _gratitude.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('MMMM d., EEEE', 'hu').format(widget.date)),
        actions: [
          if (widget.existing != null)
            IconButton(
              tooltip: 'Törlés',
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                StoreScope.of(context).removeEntry(widget.existing!);
                Navigator.pop(context);
              },
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(onPressed: _save, child: const Text('Mentés')),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Milyen napod van?', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var i = 1; i <= 5; i++)
                        MoodButton(mood: i, selected: _mood == i, size: 56, onTap: () => setState(() => _mood = i)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(moodLabels[_mood - 1],
                      style: TextStyle(color: AppColors.moods[_mood - 1], fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
          const SectionTitle('Miért vagy ma hálás? 🙏'),
          TextField(
            controller: _gratitude,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'pl. egy jó beszélgetés, a napsütés…'),
            maxLines: 2,
          ),
          const SectionTitle('Jegyzet a napodról'),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Mi történt ma? (nem kötelező)'),
            minLines: 4,
            maxLines: 8,
          ),
        ],
      ),
    );
  }
}
