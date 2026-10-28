import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../photos.dart';
import '../questions.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../stats.dart';
import '../widgets/tag_icon.dart';
import 'stats_screen.dart';
import 'tags_screen.dart';
import 'today_screen.dart' show MoodButton;

/// Hangulat- és hálanapló: a hét hangulata és a korábbi bejegyzések.
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  /// Kiválasztott címke a lista szűréséhez (null = mind).
  String? _filter;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final todayEntry = store.entryFor(now);
    final usedTags = MoodStats(store).tagStats().map((t) => t.tag).toList();
    final filter = usedTags.contains(_filter) ? _filter : null;
    final entries = filter == null ? store.journal : store.journal.where((j) => j.tags.contains(filter)).toList();

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
            SectionTitle('Bejegyzések', trailing: filter == null ? null : '${entries.length}'),
            if (usedTags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    // A leggyakoribbak (a tagStats gyakoriság szerint rendez)
                    for (final t in usedTags.take(8))
                      ChoiceChip(
                        label: TagLabel(store.tagFor(t)),
                        showCheckmark: false,
                        selected: filter == t,
                        selectedColor: AppColors.primary.withValues(alpha: 0.18),
                        onSelected: (on) => setState(() => _filter = on ? t : null),
                      ),
                  ],
                ),
              ),
            for (final j in entries) _EntryCard(entry: j, onTap: () => openEditor(j.date, j)),
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
    final store = StoreScope.of(context);
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
                          Flexible(
                            child: Text(DateFormat('MMMM d., EEEE', 'hu').format(j.date),
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                          ),
                        ],
                      ),
                      if (j.tags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [for (final t in j.tags) _TagPill(store.tagFor(t))],
                        ),
                      ],
                      if (j.gratitude.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('🙏 ${j.gratitude}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                      if (j.answer.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(j.question, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                        Text(j.answer),
                      ],
                      if (j.note.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(j.note, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted)),
                      ],
                    ],
                  ),
                ),
              ),
              if (j.photoPath != null && Photos.supported)
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      File(j.photoPath!),
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      cacheWidth: 216,
                      errorBuilder: (_, _, _) => const SizedBox(width: 72),
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

class _TagPill extends StatelessWidget {
  const _TagPill(this.tag);

  final MoodTag tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
      child: TagLabel(tag, size: 14, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
    final days = List.generate(7, (i) => addDays(today, i - 6));
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
  late String _question =
      widget.existing?.question.isNotEmpty == true ? widget.existing!.question : questionFor(widget.date);
  late final _answer = TextEditingController(text: widget.existing?.answer);
  late String? _photo = widget.existing?.photoPath;
  late final Set<String> _tags = {...?widget.existing?.tags};
  bool _saved = false;

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Fotó készítése'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Választás a galériából'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    final path = await Photos.pick(source);
    if (path == null) return;
    // Az ebben a szerkesztésben korábban választott, de lecserélt fotó már nem kell.
    if (_photo != widget.existing?.photoPath) await Photos.delete(_photo);
    setState(() => _photo = path);
  }

  Future<void> _removePhoto() async {
    if (_photo != widget.existing?.photoPath) await Photos.delete(_photo);
    setState(() => _photo = null);
  }

  void _save() {
    final answer = _answer.text.trim();
    final oldPhoto = widget.existing?.photoPath;
    if (oldPhoto != _photo) Photos.delete(oldPhoto);
    StoreScope.of(context).saveEntry(
      (widget.existing ?? JournalEntry(id: newId(), date: widget.date, mood: _mood))
        ..mood = _mood
        ..gratitude = _gratitude.text.trim()
        ..note = _note.text.trim()
        ..question = answer.isEmpty ? '' : _question
        ..answer = answer
        ..photoPath = _photo
        ..tags = [for (final t in StoreScope.of(context).moodTags) if (_tags.contains(t.id)) t.id],
    );
    _saved = true;
    Navigator.pop(context);
  }

  @override
  void dispose() {
    // Mentés nélkül kilépve az újonnan választott fotót eldobjuk.
    if (!_saved && _photo != widget.existing?.photoPath) Photos.delete(_photo);
    _gratitude.dispose();
    _note.dispose();
    _answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('MMMM d., EEEE', 'hu').format(widget.date)),
        actions: [
          if (widget.existing != null)
            IconButton(
              tooltip: 'Törlés',
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                Photos.delete(widget.existing!.photoPath);
                if (_photo != widget.existing!.photoPath) Photos.delete(_photo);
                _saved = true;
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
          SectionTitle('Hogy érzed magad?', trailing: _tags.isEmpty ? null : '${_tags.length}'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              // A rejtett címkék közül csak azok, amik ennél a napnál már ki vannak jelölve.
              for (final t in store.moodTags)
                if (t.visible || _tags.contains(t.id))
                  FilterChip(
                    label: TagLabel(t),
                    showCheckmark: false,
                    selected: _tags.contains(t.id),
                    selectedColor: AppColors.primary.withValues(alpha: 0.18),
                    onSelected: (on) => setState(() => on ? _tags.add(t.id) : _tags.remove(t.id)),
                  ),
              ActionChip(
                avatar: const Icon(Icons.tune, size: 18, color: AppColors.primary),
                label: const Text('Szerkesztés', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TagsScreen())),
              ),
            ],
          ),
          const SectionTitle('Miért vagy ma hálás? 🙏'),
          TextField(
            controller: _gratitude,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'pl. egy jó beszélgetés, a napsütés…'),
            maxLines: 2,
          ),
          if (Photos.supported) ...[
            const SectionTitle('A nap fotója 📷'),
            if (_photo == null)
              Card(
                margin: EdgeInsets.zero,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _pickPhoto,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Column(
                      children: [
                        Icon(Icons.add_a_photo_outlined, size: 32, color: AppColors.primary),
                        SizedBox(height: 8),
                        Text('Egy kép, ami megörökíti a napot', style: TextStyle(color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    Image.file(File(_photo!), height: 240, width: double.infinity, fit: BoxFit.cover),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Row(
                        children: [
                          IconButton.filledTonal(
                            tooltip: 'Csere',
                            icon: const Icon(Icons.swap_horiz),
                            onPressed: _pickPhoto,
                          ),
                          IconButton.filledTonal(
                            tooltip: 'Eltávolítás',
                            icon: const Icon(Icons.close),
                            onPressed: _removePhoto,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SectionTitle('A nap kérdése ❓'),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          layoutBuilder: (current, previous) => Stack(
                            alignment: Alignment.centerLeft,
                            children: [...previous, ?current],
                          ),
                          child: Text(
                            _question,
                            key: ValueKey(_question),
                            style: theme.textTheme.titleMedium?.copyWith(color: AppColors.primary),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Másik kérdés',
                        icon: const Icon(Icons.shuffle, color: AppColors.textMuted),
                        onPressed: () => setState(() => _question = nextQuestion(_question)),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: TextField(
                      controller: _answer,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Válaszod (nem kötelező)',
                        fillColor: AppColors.background,
                      ),
                      maxLines: 3,
                      minLines: 1,
                    ),
                  ),
                ],
              ),
            ),
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
