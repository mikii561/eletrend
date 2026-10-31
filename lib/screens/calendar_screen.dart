import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../formatting.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'event_detail_screen.dart';
import 'event_editor.dart';
import 'google_calendar_screen.dart';
import 'task_editor.dart';

enum CalendarView {
  day('Nap'),
  week('Hét'),
  month('Hónap'),
  list('Lista');

  const CalendarView(this.label);

  final String label;
}

/// A naptár négy nézettel. Üres időpontra koppintva ott kezdődik az új bejegyzés.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  /// Az utoljára használt nézet (a fülek közti váltáskor megmarad).
  static CalendarView lastView = CalendarView.week;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarView _view = CalendarScreen.lastView;
  DateTime _focus = startOfDay(DateTime.now());

  void _setView(CalendarView v) => setState(() {
    _view = v;
    CalendarScreen.lastView = v;
  });

  /// Előre/hátra a nézetnek megfelelő lépéssel.
  void _step(int dir) => setState(() {
    _focus = switch (_view) {
      CalendarView.day => DateTime(_focus.year, _focus.month, _focus.day + dir),
      CalendarView.week || CalendarView.list => DateTime(_focus.year, _focus.month, _focus.day + 7 * dir),
      CalendarView.month => DateTime(_focus.year, _focus.month + dir, 1),
    };
  });

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _focus,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _focus = startOfDay(picked));
  }

  void _openDay(DateTime d) => setState(() {
    _focus = startOfDay(d);
    _view = CalendarView.day;
    CalendarScreen.lastView = CalendarView.day;
  });

  String get _title => switch (_view) {
    CalendarView.month => DateFormat('yyyy. MMMM', 'hu').format(_focus),
    CalendarView.day => DateFormat('MMM d., EEE', 'hu').format(_focus),
    _ => DateFormat('yyyy. MMMM', 'hu').format(_focus),
  };

  /// Új bejegyzés az adott időpontra (vagy a fókuszban lévő napon a következő egész órára).
  void _create([DateTime? at]) {
    final now = DateTime.now();
    final start =
        at ??
        (sameDay(_focus, now)
            ? DateTime(now.year, now.month, now.day, now.hour + 1)
            : DateTime(_focus.year, _focus.month, _focus.day, 9));
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventEditor(initialStart: start)));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(_title, overflow: TextOverflow.ellipsis)),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Google Naptár',
            icon: Icon(store.googleConnected ? Icons.sync : Icons.add_link),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GoogleCalendarScreen())),
          ),
          IconButton(tooltip: 'Előző', icon: const Icon(Icons.chevron_left), onPressed: () => _step(-1)),
          IconButton(tooltip: 'Következő', icon: const Icon(Icons.chevron_right), onPressed: () => _step(1)),
          TextButton(onPressed: () => setState(() => _focus = startOfDay(DateTime.now())), child: const Text('Ma')),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<CalendarView>(
                showSelectedIcon: false,
                segments: [for (final v in CalendarView.values) ButtonSegment(value: v, label: Text(v.label))],
                selected: {_view},
                onSelectionChanged: (s) => _setView(s.first),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Új bejegyzés',
        onPressed: () => _create(),
        child: const Icon(Icons.add),
      ),
      body: GestureDetector(
        // Oldalra húzással is lehet lapozni.
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v.abs() > 300) _step(v < 0 ? 1 : -1);
        },
        child: switch (_view) {
          CalendarView.month => _MonthView(
            store: store,
            focus: _focus,
            onSelect: (d) => setState(() => _focus = d),
            onOpenDay: _openDay,
          ),
          CalendarView.week => _WeekView(store: store, focus: _focus, onOpenDay: _openDay, onCreate: _create),
          CalendarView.day => _DayView(
            store: store,
            day: _focus,
            onCreate: _create,
            onSelect: (d) => setState(() => _focus = d),
          ),
          CalendarView.list => _ListView(store: store, from: _focus),
        },
      ),
    );
  }
}

/// Egy elem az idővonalon (bejegyzés-alkalom vagy beosztott feladat).
class _Block {
  _Block({
    required this.start,
    required this.end,
    required this.title,
    required this.color,
    required this.onTap,
    this.task = false,
    this.subtitle,
  });

  final DateTime start;
  final DateTime end;
  final String title;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool task;

  /// Az átfedések miatti oszlop és az oszlopok száma (az elrendezés tölti ki).
  int col = 0;
  int cols = 1;
}

List<_Block> _blocksFor(BuildContext context, AppStore store, DateTime day) {
  final s = startOfDay(day);
  final e = DateTime(s.year, s.month, s.day + 1);
  return [
    for (final o in store.occurrencesBetween(s, e))
      if (!o.event.allDay)
        _Block(
          start: o.start.isBefore(s) ? s : o.start,
          end: o.end.isAfter(e) ? e : o.end,
          title: o.event.title,
          subtitle: o.event.place.isEmpty ? null : o.event.place,
          color: AppColors.ofEvent(o.event),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EventDetailScreen(eventId: o.event.id, start: o.start),
            ),
          ),
        ),
    for (final t in store.tasks)
      if (t.scheduled != null && sameDay(t.scheduled!, day))
        _Block(
          start: t.scheduled!,
          end: t.scheduled!.add(Duration(minutes: t.durationMin)),
          title: t.done ? '✓ ${t.title}' : t.title,
          color: AppColors.category(t.category),
          task: true,
          onTap: () => showTaskEditor(context, task: t),
        ),
  ];
}

/// Egymást átfedő elemek egymás mellé kerülnek.
void _layout(List<_Block> blocks) {
  blocks.sort((a, b) => a.start.compareTo(b.start));
  var cluster = <_Block>[];
  DateTime? clusterEnd;
  void flush() {
    final colEnds = <DateTime>[];
    for (final b in cluster) {
      var c = colEnds.indexWhere((end) => !end.isAfter(b.start));
      if (c < 0) {
        colEnds.add(b.end);
        c = colEnds.length - 1;
      } else {
        colEnds[c] = b.end;
      }
      b.col = c;
    }
    for (final b in cluster) {
      b.cols = colEnds.length;
    }
    cluster = [];
  }

  for (final b in blocks) {
    // Ha az előzőek már mind véget értek, új csoport kezdődik.
    if (cluster.isNotEmpty && !b.start.isBefore(clusterEnd!)) flush();
    cluster.add(b);
    clusterEnd = cluster.length == 1 || b.end.isAfter(clusterEnd!) ? b.end : clusterEnd;
  }
  flush();
}

const _hourHeight = 52.0;
const _gutter = 44.0;

/// A „most” jelző színe (piros, sötét módban világosabb).
Color get _nowColor => AppColors.dark ? const Color(0xFFFF6B5E) : const Color(0xFFD93025);

/// Idővonal egy vagy több napra (nap- és hétnézet).
class _Timeline extends StatefulWidget {
  const _Timeline({required this.days, required this.blocks, required this.onCreate});

  final List<DateTime> days;
  final List<List<_Block>> blocks;
  final void Function(DateTime at) onCreate;

  @override
  State<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<_Timeline> {
  // Reggel 7 körül nyílik, hogy ne az éjszaka látsszon.
  late final _scroll = ScrollController(initialScrollOffset: _hourHeight * 7);
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // A „most” vonal percenként halad.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final showsToday = widget.days.any((d) => sameDay(d, now));
    for (final list in widget.blocks) {
      _layout(list);
    }
    return SingleChildScrollView(
      controller: _scroll,
      child: SizedBox(
        height: _hourHeight * 24 + 16,
        child: LayoutBuilder(
          builder: (context, c) {
            final colWidth = (c.maxWidth - _gutter - 8) / widget.days.length;
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: (d) {
                final x = d.localPosition.dx - _gutter;
                if (x < 0) return;
                final dayIndex = min(widget.days.length - 1, (x / colWidth).floor());
                final minutes = ((d.localPosition.dy - 8) / _hourHeight * 60).clamp(0, 23 * 60 + 30).toInt();
                final day = widget.days[dayIndex];
                widget.onCreate(DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60 < 30 ? 0 : 30));
              },
              child: Stack(
                children: [
                  for (var h = 0; h < 24; h++) ...[
                    Positioned(
                      top: 8 + h * _hourHeight,
                      left: _gutter,
                      right: 0,
                      child: Divider(height: 1, color: AppColors.divider),
                    ),
                    Positioned(
                      top: h * _hourHeight,
                      left: 0,
                      width: _gutter - 6,
                      child: Text(
                        h == 0 || (showsToday && ((now.hour * 60 + now.minute) - h * 60).abs() < 15)
                            ? ''
                            : '${h.toString().padLeft(2, '0')}:00',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ),
                  ],
                  for (var i = 1; i < widget.days.length; i++)
                    Positioned(
                      top: 8,
                      bottom: 8,
                      left: _gutter + i * colWidth,
                      child: VerticalDivider(width: 1, color: AppColors.divider),
                    ),
                  for (var i = 0; i < widget.days.length; i++)
                    for (final b in widget.blocks[i])
                      Positioned(
                        top: 8 + (b.start.hour * 60 + b.start.minute) / 60 * _hourHeight,
                        height: max(20, b.end.difference(b.start).inMinutes / 60 * _hourHeight - 2),
                        left: _gutter + i * colWidth + b.col * (colWidth / b.cols) + 1,
                        width: colWidth / b.cols - 2,
                        child: _BlockTile(block: b, compact: widget.days.length > 1),
                      ),
                  for (var i = 0; i < widget.days.length; i++)
                    if (sameDay(widget.days[i], now)) ...[
                      // A „most” jelző: piros vonal pöttyel, bal oldalt a pontos idővel (Google/Apple naptár
                      // mintájára), hogy ne lehessen összetéveszteni egy bejegyzéssel.
                      Positioned(
                        top: 8 + (now.hour * 60 + now.minute) / 60 * _hourHeight - 7,
                        left: 0,
                        width: _gutter - 4,
                        child: Text(
                          formatTime(now),
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _nowColor),
                        ),
                      ),
                      Positioned(
                        top: 8 + (now.hour * 60 + now.minute) / 60 * _hourHeight - 4,
                        left: _gutter + i * colWidth - 4,
                        width: colWidth + 4,
                        child: Semantics(
                          label: 'Most: ${formatTime(now)}',
                          child: Row(
                            children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(color: _nowColor, shape: BoxShape.circle)),
                              Expanded(child: Container(height: 2, color: _nowColor)),
                            ],
                          ),
                        ),
                      ),
                    ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BlockTile extends StatelessWidget {
  const _BlockTile({required this.block, required this.compact});

  final _Block block;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final b = block;
    final bg = b.color.withValues(alpha: AppColors.dark ? 0.32 : 0.16);
    return Semantics(
      button: true,
      label: '${b.title}, ${formatTime(b.start)}–${formatTime(b.end)}',
      child: GestureDetector(
        onTap: b.onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: compact ? 3 : 8, vertical: 3),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: b.task
                ? Border.all(color: b.color, width: 1.2)
                : Border(left: BorderSide(color: b.color, width: 3)),
          ),
          child: ClipRect(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.title,
                  maxLines: compact ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 11 : 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                    height: 1.15,
                  ),
                ),
                if (!compact)
                  Text(
                    [formatRange(b.start, b.end), ?b.subtitle].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Egész napos bejegyzések sávja a nap/hét nézet tetején.
class _AllDayRow extends StatelessWidget {
  const _AllDayRow({required this.store, required this.days});

  final AppStore store;
  final List<DateTime> days;

  @override
  Widget build(BuildContext context) {
    final perDay = [for (final d in days) store.occurrencesOn(d).where((o) => o.event.allDay).toList()];
    if (perDay.every((l) => l.isEmpty)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: _gutter, right: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final list in perDay)
            Expanded(
              child: Column(
                children: [
                  for (final o in list)
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EventDetailScreen(eventId: o.event.id, start: o.start),
                        ),
                      ),
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.all(1),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.ofEvent(o.event),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          o.event.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A fókuszban lévő hét hétfője.
DateTime _monday(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

class _WeekView extends StatelessWidget {
  const _WeekView({required this.store, required this.focus, required this.onOpenDay, required this.onCreate});

  final AppStore store;
  final DateTime focus;
  final ValueChanged<DateTime> onOpenDay;
  final void Function(DateTime at) onCreate;

  @override
  Widget build(BuildContext context) {
    final monday = _monday(focus);
    final days = [for (var i = 0; i < 7; i++) DateTime(monday.year, monday.month, monday.day + i)];
    final today = DateTime.now();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: _gutter, right: 8, bottom: 4),
          child: Row(
            children: [
              for (final d in days)
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onOpenDay(d),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          Text(
                            DateFormat.E('hu').format(d),
                            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 2),
                          _DayNumber(day: d, today: sameDay(d, today), selected: false),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        _AllDayRow(store: store, days: days),
        Divider(height: 1, color: AppColors.divider),
        Expanded(
          child: _Timeline(
            days: days,
            blocks: [for (final d in days) _blocksFor(context, store, d)],
            onCreate: onCreate,
          ),
        ),
      ],
    );
  }
}

class _DayNumber extends StatelessWidget {
  const _DayNumber({required this.day, required this.today, required this.selected});

  final DateTime day;
  final bool today;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final filled = today || selected;
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: today ? AppColors.primary : (selected ? AppColors.primary.withValues(alpha: 0.15) : null),
        shape: BoxShape.circle,
      ),
      child: Text(
        '${day.day}',
        style: TextStyle(
          fontWeight: filled ? FontWeight.w700 : FontWeight.w500,
          color: today ? AppColors.onPrimary : AppColors.text,
        ),
      ),
    );
  }
}

class _DayView extends StatelessWidget {
  const _DayView({required this.store, required this.day, required this.onCreate, required this.onSelect});

  final AppStore store;
  final DateTime day;
  final void Function(DateTime at) onCreate;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final monday = _monday(day);
    final week = [for (var i = 0; i < 7; i++) DateTime(monday.year, monday.month, monday.day + i)];
    final today = DateTime.now();
    final unscheduled = store.tasksOn(day).where((t) => t.scheduled == null).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              for (final d in week)
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onSelect(d),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          Text(
                            DateFormat.E('hu').format(d),
                            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 2),
                          _DayNumber(day: d, today: sameDay(d, today), selected: sameDay(d, day)),
                          const SizedBox(height: 2),
                          _Dots(colors: _dayColors(store, d), max: 3),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        _AllDayRow(store: store, days: [day]),
        if (unscheduled.isNotEmpty)
          Card(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Text(
                    'Feladatok erre a napra',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                for (final t in unscheduled.take(4)) TaskTile(task: t, dense: true),
                if (unscheduled.length > 4)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Text('és még ${unscheduled.length - 4}', style: TextStyle(color: AppColors.textMuted)),
                  ),
              ],
            ),
          ),
        Divider(height: 1, color: AppColors.divider),
        Expanded(
          child: _Timeline(days: [day], blocks: [_blocksFor(context, store, day)], onCreate: onCreate),
        ),
      ],
    );
  }
}

/// Egy nap színei (bejegyzések és beosztott feladatok), a pöttyökhöz.
List<Color> _dayColors(AppStore store, DateTime day) => [
  for (final o in store.occurrencesOn(day)) AppColors.ofEvent(o.event),
  for (final t in store.tasksOn(day, now: DateTime(1900))) AppColors.category(t.category),
];

class _Dots extends StatelessWidget {
  const _Dots({required this.colors, this.max = 3});

  final List<Color> colors;
  final int max;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 6,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final c in colors.take(max))
            Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }
}

class _MonthView extends StatelessWidget {
  const _MonthView({required this.store, required this.focus, required this.onSelect, required this.onOpenDay});

  final AppStore store;
  final DateTime focus;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<DateTime> onOpenDay;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(focus.year, focus.month, 1);
    final gridStart = _monday(first);
    final today = DateTime.now();
    final cells = [for (var i = 0; i < 42; i++) DateTime(gridStart.year, gridStart.month, gridStart.day + i)];
    final rows = cells.last.month != focus.month && cells[35].month != focus.month ? 5 : 6;
    final occ = store.occurrencesOn(focus);
    final tasks = store.tasksOn(focus);
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 96),
      children: [
        Row(
          children: [
            for (final w in ['H', 'K', 'Sze', 'Cs', 'P', 'Szo', 'V'])
              Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (final d in cells.skip(r * 7).take(7))
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onSelect(d),
                    onDoubleTap: () => onOpenDay(d),
                    child: SizedBox(
                      height: 58,
                      child: Opacity(
                        opacity: d.month == focus.month ? 1 : 0.4,
                        child: Column(
                          children: [
                            const SizedBox(height: 4),
                            _DayNumber(day: d, today: sameDay(d, today), selected: sameDay(d, focus)),
                            const SizedBox(height: 4),
                            _Dots(colors: _dayColors(store, d), max: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
          child: Row(
            children: [
              Expanded(child: Text(formatDay(focus), style: Theme.of(context).textTheme.titleMedium)),
              TextButton(onPressed: () => onOpenDay(focus), child: const Text('Napi nézet')),
            ],
          ),
        ),
        _DayAgenda(occurrences: occ, tasks: tasks),
      ],
    );
  }
}

/// Egy nap listája: bejegyzések időrendben, alattuk a feladatok.
class _DayAgenda extends StatelessWidget {
  const _DayAgenda({required this.occurrences, required this.tasks});

  final List<Occurrence> occurrences;
  final List<TaskItem> tasks;

  @override
  Widget build(BuildContext context) {
    if (occurrences.isEmpty && tasks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Szabad nap. Koppints a + gombra, ha tervezel valamit.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return Card(
      child: Column(
        children: [
          for (final o in occurrences) OccurrenceTile(occurrence: o),
          for (final t in tasks) TaskTile(task: t),
        ],
      ),
    );
  }
}

/// Egy alkalom a listákban: színes csík, cím, idő, hely.
class OccurrenceTile extends StatelessWidget {
  const OccurrenceTile({super.key, required this.occurrence, this.showDay = false});

  final Occurrence occurrence;
  final bool showDay;

  @override
  Widget build(BuildContext context) {
    final o = occurrence;
    final color = AppColors.ofEvent(o.event);
    final when = formatRange(o.start, o.end, allDay: o.event.allDay);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: Container(
        width: 4,
        height: 40,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
      ),
      title: Text(
        o.event.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [if (showDay) formatDay(o.start, short: true), when, if (o.event.place.isNotEmpty) o.event.place].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: o.event.isShared
          ? Icon(Icons.groups_outlined, size: 18, color: AppColors.category(EventCategory.shared))
          : null,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EventDetailScreen(eventId: o.event.id, start: o.start),
        ),
      ),
    );
  }
}

class _ListView extends StatelessWidget {
  const _ListView({required this.store, required this.from});

  final AppStore store;
  final DateTime from;

  @override
  Widget build(BuildContext context) {
    final start = startOfDay(from);
    final days = [for (var i = 0; i < 60; i++) DateTime(start.year, start.month, start.day + i)];
    final sections = <Widget>[];
    for (final d in days) {
      final occ = store.occurrencesOn(d);
      final tasks = store.tasksOn(d, now: DateTime(1900)).where((t) => !t.done).toList();
      if (occ.isEmpty && tasks.isEmpty) continue;
      sections
        ..add(
          SectionTitle(
            formatDay(d),
            trailing: sameDay(d, DateTime.now()) || formatDay(d).length > 7
                ? null
                : DateFormat('MMM d.', 'hu').format(d),
          ),
        )
        ..add(_DayAgenda(occurrences: occ, tasks: tasks));
    }
    if (sections.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [EmptyState(emoji: '🗓️', text: 'A következő 60 napban nincs semmi a naptáradban.')],
      );
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 96), children: sections);
  }
}
