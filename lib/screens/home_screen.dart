import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../availability_service.dart';
import '../challenges.dart';
import '../formatting.dart';
import '../memories.dart';
import '../friends.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/goal_widgets.dart';
import '../widgets/app_tour.dart';
import '../widgets/install_card.dart';
import 'calendar_screen.dart' show OccurrenceTile;
import 'challenges_screen.dart';
import 'event_detail_screen.dart';
import 'event_editor.dart';
import 'find_time_screen.dart';
import 'habits_screen.dart';
import 'invite_screen.dart';
import 'memory_screen.dart';
import 'status_sheet.dart';
import 'task_editor.dart';

/// Főoldal: a napod áttekintése. A kártyák sorrendje és láthatósága a Profilban állítható.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onNavigate});

  /// Fülváltás (pl. a „Naptár” linkről).
  final ValueChanged<int> onNavigate;

  static String greeting(DateTime now) => switch (now.hour) {
    >= 5 && < 10 => 'Jó reggelt',
    >= 10 && < 18 => 'Szia',
    >= 18 && < 22 => 'Jó estét',
    _ => 'Szép éjszakát',
  };

  /// Az összefoglaló mondat, pl. „Ma 3 programod és 2 teendőd van.”
  static String summary(AppStore store, DateTime now, {int? freeFriends}) {
    final rest = store.occurrencesOn(now).where((o) => o.end.isAfter(now)).length;
    final tasks = store.tasksOn(now, now: now).where((t) => !t.done).length;
    final parts = <String>[if (rest > 0) '$rest programod', if (tasks > 0) '$tasks teendőd'];
    var text = parts.isEmpty ? 'Ma nincs több dolgod a naptárban.' : 'Ma még ${parts.join(' és ')} van.';
    if (freeFriends != null && freeFriends > 0) text += ' $freeFriends barátod most ráér.';
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final pendingInvites = store.invites
        .where((i) => !i.date.isBefore(startOfDay(now)) && !store.events.any((e) => e.shareId == i.id))
        .toList();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _Header(store: store, now: now),
            const InstallAndPushCard(),
            _NextUp(store: store, now: now),
            const SizedBox(height: 8),
            _QuickActions(onCalendar: () => onNavigate(1)),
            if (pendingInvites.isNotEmpty) ...[
              SectionTitle('Meghívásaim', trailing: '${pendingInvites.length}'),
              Card(
                child: Column(
                  children: [
                    for (final i in pendingInvites.take(5))
                      ListTile(
                        leading: DateBadge(i.date, size: 44),
                        title: Text(i.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          [
                            '${formatDay(i.date, short: true)} ${formatTime(i.date)}',
                            if (i.fromName.isNotEmpty) i.fromName,
                          ].join(' · '),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => InviteScreen(eventId: i.id))),
                      ),
                  ],
                ),
              ),
            ],
            for (final card in store.homeCards)
              if (store.showsCard(card))
                switch (card) {
                  HomeCard.schedule => _ScheduleCard(store: store, now: now, onCalendar: () => onNavigate(1)),
                  HomeCard.tasks => _TasksCard(store: store, now: now),
                  HomeCard.goals => _GoalsCard(store: store, now: now),
                  HomeCard.friends => const _FriendsCard(),
                  HomeCard.birthdays => _BirthdaysCard(store: store, now: now),
                  HomeCard.challenges => const _ChallengesCard(),
                  HomeCard.memories => _MemoryCard(store: store, now: now),
                  HomeCard.week => _WeekCard(store: store, now: now),
                },
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.store, required this.now});

  final AppStore store;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final status = store.statusAt(now);
    final name = store.myName.isEmpty ? '' : ', ${store.myName.split(' ').first}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('MMMM d., EEEE', 'hu').format(now).toUpperCase(),
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text('${HomeScreen.greeting(now)}$name', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(HomeScreen.summary(store, now), style: TextStyle(color: AppColors.textMuted)),
              ],
            ),
          ),
          Tooltip(
            message: 'Az állapotod a barátaidnak',
            child: ActionChip(
              key: TourKeys.status,
              avatar: Icon(statusIcon(status), size: 16, color: AppColors.status(status)),
              label: Text(status.label),
              onPressed: () => showStatusSheet(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// A legközelebbi (még nem véget ért) alkalom kiemelve.
class _NextUp extends StatelessWidget {
  const _NextUp({required this.store, required this.now});

  final AppStore store;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final next = store.upcoming(days: 7, now: now).where((o) => !o.event.allDay).firstOrNull;
    if (next == null) return const SizedBox.shrink();
    final color = AppColors.ofEvent(next.event);
    final running = !next.start.isAfter(now);
    final minutes = next.start.difference(now).inMinutes;
    final when = running
        ? 'Most tart · ${formatTime(next.end)}-ig'
        : minutes < 60
        ? '$minutes perc múlva'
        : sameDay(next.start, now)
        ? '${formatTime(next.start)}-kor · ${formatDuration(minutes)} múlva'
        : '${formatDay(next.start)} ${formatTime(next.start)}';
    return Card(
      color: color.withValues(alpha: AppColors.dark ? 0.22 : 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Space.radius),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        leading: Icon(categoryIcon(next.event.category), color: color),
        title: Text(
          running ? 'Most' : 'Következő',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(next.event.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.text)),
            Text([when, if (next.event.place.isNotEmpty) next.event.place].join(' · ')),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EventDetailScreen(eventId: next.event.id, start: next.start),
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onCalendar});

  final VoidCallback onCalendar;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, String label, VoidCallback onTap) => Expanded(
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, overflow: TextOverflow.ellipsis),
      ),
    );
    return Row(
      key: TourKeys.quickActions,
      children: [
        button(
          Icons.event_outlined,
          'Bejegyzés',
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EventEditor())),
        ),
        const SizedBox(width: 8),
        button(Icons.add_task, 'Feladat', () => showTaskEditor(context, due: DateTime.now())),
        const SizedBox(width: 8),
        button(
          Icons.group_outlined,
          'Közös idő',
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FindTimeScreen())),
        ),
      ],
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.store, required this.now, required this.onCalendar});

  final AppStore store;
  final DateTime now;
  final VoidCallback onCalendar;

  @override
  Widget build(BuildContext context) {
    final today = store.occurrencesOn(now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(HomeCard.schedule.label, trailing: today.isEmpty ? null : '${today.length}', onMore: onCalendar),
        if (today.isEmpty)
          Card(
            child: ListTile(
              leading: IconTile(Icons.wb_sunny_outlined, color: AppColors.accent),
              title: const Text('Szabad napod van'),
              subtitle: const Text('Szervezz valamit a barátaiddal, vagy foglalj időt magadra.'),
            ),
          )
        else
          Card(
            child: Column(children: [for (final o in today) OccurrenceTile(occurrence: o)]),
          ),
      ],
    );
  }
}

class _TasksCard extends StatelessWidget {
  const _TasksCard({required this.store, required this.now});

  final AppStore store;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final today = store.tasksOn(now, now: now);
    final open = store.openTasks;
    // Előbb a mai (és lejárt) feladatok, aztán a határidő nélküliek.
    final shown = [...today, ...open.where((t) => t.day == null && !today.contains(t))].take(6).toList();
    final left = today.where((t) => !t.done).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(HomeCard.tasks.label, trailing: left == 0 ? null : '$left ma'),
        Card(
          child: Column(
            children: [
              if (shown.isEmpty)
                const ListTile(
                  title: Text('Nincs nyitott feladatod.'),
                  subtitle: Text('Írd fel, ami a fejedben jár, hogy ne ott kelljen tartanod.'),
                ),
              for (final t in shown) TaskTile(task: t),
              ListTile(
                leading: Icon(Icons.add, color: AppColors.primary),
                title: Text(
                  'Új feladat',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
                onTap: () => showTaskEditor(context, due: now),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GoalsCard extends StatelessWidget {
  const _GoalsCard({required this.store, required this.now});

  final AppStore store;
  final DateTime now;

  void _open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HabitsScreen()));

  @override
  Widget build(BuildContext context) {
    final habits = store.habits;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          HomeCard.goals.label,
          trailing: habits.isEmpty ? null : '${habits.length - store.habitsLeftToday}/${habits.length}',
          onMore: () => _open(context),
        ),
        if (habits.isEmpty)
          Card(
            child: ListTile(
              leading: const IconTile(Icons.flag_outlined),
              title: const Text('Tűzz ki egy célt'),
              subtitle: const Text('Pl. hetente 3× edzés, napi 20 oldal olvasás. Csak te látod.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(context),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (final h in habits.take(5))
                  ListTile(
                    leading: CheckCircle(done: h.isDoneOn(now), size: 30, onTap: () => store.toggleHabit(h)),
                    title: Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: habitProgress(h, now) == null ? null : Text(habitProgress(h, now)!),
                    trailing: StreakChip(h.streak(), unit: h.streakUnit),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Kik érnek rá most (azok közül, akik megosztják az elérhetőségüket).
class _FriendsCard extends StatefulWidget {
  const _FriendsCard();

  @override
  State<_FriendsCard> createState() => _FriendsCardState();
}

class _FriendsCardState extends State<_FriendsCard> {
  Future<Map<String, FriendAvailability?>>? _future;
  String _key = '';

  void _load(AppStore store) {
    final key = store.friendsCache.map((f) => f.uid).join(',');
    if (_future != null && key == _key) return;
    _key = key;
    _future = Friends.instance.ready && store.friendsCache.isNotEmpty
        ? AvailabilityService.instance.fetchAll(store.friendsCache.map((f) => f.uid))
        : Future.value(const {});
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    _load(store);
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(HomeCard.friends.label),
        if (store.friendsCache.isEmpty)
          const Card(
            child: ListTile(
              leading: IconTile(Icons.person_add_alt_outlined),
              title: Text('Hívd meg a barátaidat'),
              subtitle: Text('A Barátok fülön megtalálod a kódodat. Ha ők is fent vannak, látjátok, ki mikor ér rá.'),
            ),
          )
        else
          FutureBuilder<Map<String, FriendAvailability?>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const Card(child: LoadingState());
              final data = snap.data ?? const {};
              final free = [
                for (final f in store.friendsCache)
                  if (data[f.uid] case final a?)
                    if (a.statusAt(now) == AvailabilityStatus.available || a.statusAt(now) == AvailabilityStatus.open)
                      (f, a.statusAt(now)),
              ];
              return Card(
                child: Column(
                  children: [
                    if (free.isEmpty)
                      ListTile(
                        title: const Text('Most senki sem jelezte, hogy ráér.'),
                        subtitle: Text(
                          data.values.every((a) => a == null)
                              ? 'A barátaid még nem osztják meg az elérhetőségüket.'
                              : 'Nézd meg, mikor lesz közös szabad időtök.',
                        ),
                      ),
                    for (final (f, status) in free.take(5))
                      ListTile(
                        leading: Badge(
                          backgroundColor: AppColors.status(status),
                          smallSize: 10,
                          alignment: Alignment.bottomRight,
                          child: NameAvatar(f.name),
                        ),
                        title: Text(f.name),
                        subtitle: Text(status.label),
                      ),
                    ListTile(
                      leading: Icon(Icons.event_available_outlined, color: AppColors.primary),
                      title: Text(
                        'Közös időpont keresése',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                      onTap: () =>
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FindTimeScreen())),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _BirthdaysCard extends StatelessWidget {
  const _BirthdaysCard({required this.store, required this.now});

  final AppStore store;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final soon = [
      for (final f in store.friendsCache)
        if (f.nextBirthday(now) case final d? when d.difference(startOfDay(now)).inDays <= 30) (f.name, d),
      if (store.birthday != null && store.birthday!.length == 10)
        if (nextBirthdayOf(store.birthday!.substring(5), now) case final d?
            when d.difference(startOfDay(now)).inDays <= 30)
          ('Te', d),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    if (soon.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(HomeCard.birthdays.label),
        Card(
          child: Column(
            children: [
              for (final (name, day) in soon.take(5))
                ListTile(
                  leading: const IconTile(Icons.cake_outlined),
                  title: Text(name),
                  subtitle: Text(
                    sameDay(day, now)
                        ? 'Ma! 🎉'
                        : '${formatDay(day)} · ${day.difference(startOfDay(now)).inDays} nap múlva',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChallengesCard extends StatefulWidget {
  const _ChallengesCard();

  @override
  State<_ChallengesCard> createState() => _ChallengesCardState();
}

class _ChallengesCardState extends State<_ChallengesCard> {
  Stream<List<Challenge>>? _stream;

  @override
  Widget build(BuildContext context) {
    if (!Friends.instance.ready) return const SizedBox.shrink();
    _stream ??= Challenges.instance.watchMine();
    return StreamBuilder<List<Challenge>>(
      stream: _stream,
      builder: (context, snap) {
        final active = (snap.data ?? const <Challenge>[]).where((c) => !c.isGoal && c.isActive()).toList();
        if (active.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(
              HomeCard.challenges.label,
              onMore: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChallengesScreen())),
            ),
            Card(
              child: Column(
                children: [
                  for (final c in active.take(3))
                    ListTile(
                      leading: Text(c.emoji, style: const TextStyle(fontSize: 24)),
                      title: Text(c.title),
                      subtitle: Text('${c.dayNumber()}. nap a ${c.days}-ból · ${c.members.length} fő'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChallengeDetail(challenge: c))),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Egy felbukkanó emlék egy közös programról: mi volt, mikor, hol, és a közös fotók.
class _MemoryCard extends StatelessWidget {
  const _MemoryCard({required this.store, required this.now});

  final AppStore store;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final pick = pickMemory(store.events, now);
    if (pick == null) return const SizedBox.shrink();
    final e = pick.event;
    void open() => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MemoryScreen(eventId: e.shareId!, title: e.title, start: pick.occurredAt, place: e.place),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(HomeCard.memories.label, trailing: pick.anniversary ? 'ma ${pick.ago}' : pick.ago),
        Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: open,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconTile(Icons.photo_library_outlined, color: AppColors.category(EventCategory.shared)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.title, style: Theme.of(context).textTheme.titleMedium),
                            Text(
                              [
                                DateFormat('yyyy. MMMM d., EEEE', 'hu').format(pick.occurredAt),
                                if (e.place.isNotEmpty) e.place,
                              ].join(' · '),
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  MemoryStrip(eventId: e.shareId!, going: false, canUpload: false, onOpen: open),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A hét röviden: amit csináltál, nem túl sok számmal.
class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.store, required this.now});

  final AppStore store;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final s = WeekStats.of(store, now);
    Widget tile(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(HomeCard.week.label, trailing: 'hétfő óta'),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Row(
              children: [
                tile('${s.events}', 'program'),
                tile('${s.social}', 'közös'),
                tile('${s.tasksDone}', 'kész feladat'),
                tile('${s.goalDays}', 'célnap'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A hét számai (hétfőtől máig).
class WeekStats {
  const WeekStats({required this.events, required this.social, required this.tasksDone, required this.goalDays});

  final int events;
  final int social;
  final int tasksDone;
  final int goalDays;

  factory WeekStats.of(AppStore store, DateTime now) {
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final occ = store.occurrencesBetween(monday, now);
    return WeekStats(
      events: occ.length,
      social: occ.where((o) => o.event.isShared || o.event.category == EventCategory.social).length,
      tasksDone: store.tasks.where((t) => t.done && t.doneAt != null && !t.doneAt!.isBefore(monday)).length,
      goalDays: store.habits.fold(0, (sum, h) => sum + h.doneBetween(monday, now)),
    );
  }
}
