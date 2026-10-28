import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../account.dart';
import '../admin.dart';
import '../community.dart';
import '../geocoding.dart';
import '../ideas.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'events_screen.dart';
import 'location_picker.dart';

/// A közösségi ötletek egy betöltése: ötletek, pontszámok, a saját szavazataim.
class CommunityData {
  const CommunityData(this.ideas, this.scores, this.mine);

  final List<CommunityIdea> ideas;
  final Map<String, IdeaScore> scores;
  final Map<String, MyVote> mine;

  static Future<CommunityData> load() async {
    final ideas = await Community.instance.latest();
    final votes = await Community.instance.votes(Account.instance.user?.uid);
    return CommunityData(ideas, votes.scores, votes.mine);
  }

  /// Az ötletekben előforduló országok, ábécérendben.
  List<String> get countries => ({for (final i in ideas) if (i.place.country.isNotEmpty) i.place.country}.toList()..sort());

  List<String> citiesIn(String country) =>
      ({for (final i in ideas) if (i.place.country == country && i.place.city.isNotEmpty) i.place.city}.toList()..sort());
}

void _error(BuildContext context, Object e) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nem sikerült. Van internet? ($e)')));

/// Helyszín kiválasztása a térképen, várossal és országgal kiegészítve.
Future<IdeaPlace?> pickIdeaPlace(BuildContext context, {IdeaPlace? initial}) async {
  final picked = await Navigator.of(context).push<Place>(MaterialPageRoute(
    builder: (_) => LocationPicker(
      initial: initial != null && initial.hasPoint ? Place(name: initial.name, point: LatLng(initial.lat!, initial.lng!)) : null,
    ),
  ));
  if (picked == null) return null;
  final region = await Geocoding.region(picked.point);
  return IdeaPlace(
    name: picked.name,
    city: region?.city ?? '',
    country: region?.country ?? '',
    lat: picked.point.latitude,
    lng: picked.point.longitude,
  );
}

/// Szűrők: rendezés, hely (mindenhol / közelben / ország / város).
class IdeaFilter {
  IdeaSort sort = IdeaSort.rating;
  String? country;
  String? city;

  List<CommunityIdea> apply(CommunityData d, IdeaPlace? home) =>
      sortAndFilter(d.ideas, d.scores, sort: sort, country: country, city: city, home: home);
}

/// A szűrősor (a böngészőben és az ötletadóban is ez van).
class IdeaFilterBar extends StatelessWidget {
  const IdeaFilterBar({super.key, required this.filter, required this.data, required this.onChanged});

  final IdeaFilter filter;
  final CommunityData data;
  final VoidCallback onChanged;

  Future<void> _setHome(BuildContext context) async {
    final store = StoreScope.of(context);
    final place = await pickIdeaPlace(context, initial: store.homePlace);
    if (place != null) store.setHomePlace(place);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final home = store.homePlace;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final s in IdeaSort.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(s.label),
                    selected: filter.sort == s,
                    onSelected: (_) {
                      filter.sort = s;
                      onChanged();
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (filter.sort == IdeaSort.nearby)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.home_outlined, color: AppColors.primary),
            title: Text(home == null ? 'Add meg, hol laksz' : '30 km-en belül innen: ${home.label.isEmpty ? home.name : home.label}'),
            trailing: TextButton(onPressed: () => _setHome(context), child: Text(home == null ? 'Megadás' : 'Módosítás')),
          )
        else
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: filter.country,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Ország'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Mindenhol')),
                    for (final c in data.countries) DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) {
                    filter
                      ..country = v
                      ..city = null;
                    onChanged();
                  },
                ),
              ),
              if (filter.country != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    key: ValueKey(filter.country),
                    initialValue: filter.city,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Város'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Mind')),
                      for (final c in data.citiesIn(filter.country!))
                        DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) {
                      filter.city = v;
                      onChanged();
                    },
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

/// Pontszám kiírása: ❤️ 12 · ⭐ 4,6 (8)
String scoreText(IdeaScore? s) {
  if (s == null || (s.likes == 0 && s.ratingCount == 0)) return 'Még nincs értékelése';
  return [
    '❤️ ${s.likes}',
    if (s.average != null) '⭐ ${s.average!.toStringAsFixed(1).replaceAll('.', ',')} (${s.ratingCount})',
  ].join(' · ');
}

/// Közösségi ötletek böngészése.
class CommunityIdeasScreen extends StatefulWidget {
  const CommunityIdeasScreen({super.key});

  @override
  State<CommunityIdeasScreen> createState() => _CommunityIdeasScreenState();
}

class _CommunityIdeasScreenState extends State<CommunityIdeasScreen> {
  late Future<CommunityData> _data = CommunityData.load();
  final _filter = IdeaFilter();

  void _reload() {
    final f = CommunityData.load();
    setState(() {
      _data = f;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Közösségi ötletek')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (await showShareIdeaSheet(context) == true) _reload();
        },
        icon: const Icon(Icons.lightbulb_outline),
        label: const Text('Ötlet megosztása', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: FutureBuilder<CommunityData>(
        future: _data,
        builder: (context, snap) {
          if (snap.hasError) {
            return ListView(padding: const EdgeInsets.all(16), children: [
              EmptyState(emoji: '📡', text: 'Nem sikerült betölteni.\n${snap.error}', action: 'Újra', onAction: _reload),
            ]);
          }
          final data = snap.data;
          if (data == null) return const Center(child: CircularProgressIndicator());
          final shown = _filter.apply(data, store.homePlace);
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              children: [
                IdeaFilterBar(filter: _filter, data: data, onChanged: () => setState(() {})),
                const SizedBox(height: 8),
                if (shown.isEmpty)
                  EmptyState(
                    emoji: '💡',
                    text: data.ideas.isEmpty
                        ? 'Még senki nem osztott meg ötletet.\nLegyél te az első!'
                        : 'Erre a szűrésre nincs ötlet.\nPróbálj tágabb helyet vagy más rendezést.',
                  ),
                for (final i in shown)
                  IdeaCard(
                    idea: i,
                    score: data.scores[i.id],
                    onTap: () async {
                      await showIdeaDetail(context, i, data);
                      _reload();
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class IdeaCard extends StatelessWidget {
  const IdeaCard({super.key, required this.idea, required this.score, required this.onTap});

  final CommunityIdea idea;
  final IdeaScore? score;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final i = idea;
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Text(i.emoji, style: const TextStyle(fontSize: 30)),
        title: Text(i.title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text([
          scoreText(score),
          [if (i.place.label.isNotEmpty) '📍 ${i.place.label}', 'ajánlotta: ${i.authorName}'].join(' · '),
        ].join('\n')),
        isThreeLine: true,
      ),
    );
  }
}

/// Egy ötlet részletei: kedvelés, csillagok, szervezés, jelentés, törlés.
Future<void> showIdeaDetail(BuildContext context, CommunityIdea idea, CommunityData data) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _IdeaDetail(idea: idea, score: data.scores[idea.id], mine: data.mine[idea.id] ?? const MyVote()),
    );

class _IdeaDetail extends StatefulWidget {
  const _IdeaDetail({required this.idea, required this.score, required this.mine});

  final CommunityIdea idea;
  final IdeaScore? score;
  final MyVote mine;

  @override
  State<_IdeaDetail> createState() => _IdeaDetailState();
}

class _IdeaDetailState extends State<_IdeaDetail> {
  late MyVote _vote = widget.mine;
  late final Future<bool> _isAdmin = Admin.instance.isAdmin(Account.instance.user?.uid ?? '');

  Future<void> _set(MyVote v) async {
    final uid = Account.instance.user?.uid;
    if (uid == null) return;
    final before = _vote;
    setState(() => _vote = v);
    try {
      await Community.instance.vote(widget.idea.id, uid, v);
    } catch (e) {
      if (!mounted) return;
      setState(() => _vote = before);
      _error(context, e);
    }
  }

  Future<void> _report() async {
    final uid = Account.instance.user?.uid;
    if (uid == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final reason = await showTextInputSheet(context, title: 'Mi a gond vele?', hint: 'pl. sértő, reklám, nem program', action: 'Jelentés');
    if (reason == null) return;
    try {
      await Community.instance.report(widget.idea.id, uid, reason);
      messenger.showSnackBar(const SnackBar(content: Text('Köszönjük, megnézzük.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Nem sikerült: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.idea;
    final isAuthor = i.authorUid == Account.instance.user?.uid;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(i.emoji, textAlign: TextAlign.center, style: const TextStyle(fontSize: 56)),
            Text(i.title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            if (i.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(i.text, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 8),
            Text(
              [if (i.place.name.isNotEmpty) '📍 ${i.place.name}', 'ajánlotta: ${i.authorName}'].join('\n'),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
            if (i.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                children: [for (final t in i.tags) Chip(label: Text(t.label), visualDensity: VisualDensity.compact)],
              ),
            ],
            const SizedBox(height: 4),
            Text(scoreText(widget.score), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
            const Divider(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: _vote.liked ? 'Kedvelés visszavonása' : 'Kedvelem',
                  iconSize: 32,
                  onPressed: () => _set(MyVote(liked: !_vote.liked, rating: _vote.rating)),
                  icon: Text(_vote.liked ? '❤️' : '🤍', style: const TextStyle(fontSize: 28)),
                ),
                const SizedBox(width: 12),
                for (var s = 1; s <= 5; s++)
                  IconButton(
                    tooltip: '$s csillag',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _set(MyVote(liked: _vote.liked, rating: _vote.rating == s ? 0 : s)),
                    icon: Icon(s <= _vote.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: const Color(0xFFFFB300), size: 30),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.push(MaterialPageRoute(
                  builder: (_) => EventEditor(
                    initialTitle: '${i.emoji} ${i.title}',
                    initialPlace: i.place.hasPoint ? Place(name: i.place.name, point: LatLng(i.place.lat!, i.place.lng!)) : null,
                  ),
                ));
              },
              child: const Text('Ezt szervezem!'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (!isAuthor) TextButton.icon(onPressed: _report, icon: const Icon(Icons.flag_outlined, size: 18), label: const Text('Jelentés')),
                const Spacer(),
                FutureBuilder<bool>(
                  future: _isAdmin,
                  builder: (context, snap) => isAuthor || snap.data == true
                      ? TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
                          onPressed: () async {
                            final navigator = Navigator.of(context);
                            try {
                              await Community.instance.delete(i.id, asAdmin: snap.data == true);
                              navigator.pop();
                            } catch (e) {
                              if (context.mounted) _error(context, e);
                            }
                          },
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Törlés'),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Ötlet megosztása mindenkivel. Igazat ad, ha megosztotta.
Future<bool?> showShareIdeaSheet(BuildContext context, {String? title, IdeaPlace? place}) => showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ShareIdea(title: title, place: place),
    );

class _ShareIdea extends StatefulWidget {
  const _ShareIdea({this.title, this.place});

  final String? title;
  final IdeaPlace? place;

  @override
  State<_ShareIdea> createState() => _ShareIdeaState();
}

class _ShareIdeaState extends State<_ShareIdea> {
  static const _emojis = ['💡', '🎬', '🎳', '🥾', '🍕', '☕', '🎲', '🧺', '🎤', '🏊', '🎨', '🚴', '🎭', '🍷', '🏕️', '🎡'];
  late final _title = TextEditingController(text: widget.title);
  final _text = TextEditingController();
  String _emoji = '💡';
  final Set<IdeaTag> _tags = {};
  late IdeaPlace? _place = widget.place;
  bool _busy = false;
  String? _error;

  Future<void> _share() async {
    final user = Account.instance.user;
    final title = _title.text.trim();
    if (title.isEmpty) return setState(() => _error = 'Adj címet az ötletnek');
    if (user == null) return;
    setState(() => _busy = true);
    try {
      // Programból érkező helynél még nincs meg a város és az ország.
      var place = _place;
      if (place != null && place.hasPoint && place.country.isEmpty) {
        final region = await Geocoding.region(LatLng(place.lat!, place.lng!));
        place = IdeaPlace(name: place.name, city: region?.city ?? '', country: region?.country ?? '', lat: place.lat, lng: place.lng);
      }
      if (!mounted) return;
      await Community.instance.publish(
        uid: user.uid,
        authorName: StoreScope.of(context).myName,
        title: title,
        emoji: _emoji,
        text: _text.text,
        tags: _tags,
        place: place ?? const IdeaPlace(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Nem sikerült megosztani: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ötlet megosztása', style: Theme.of(context).textTheme.titleLarge),
            Text('Minden Életrend-felhasználó látni fogja, és értékelheti.', style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 2,
              children: [
                for (final e in _emojis)
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _emoji = e),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: _emoji == e ? AppColors.primary.withValues(alpha: 0.18) : null,
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _title,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: 'Mi a program?', hintText: 'pl. Naplemente a Gellért-hegyen', errorText: _error, counterText: ''),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _text,
              maxLength: 300,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Pár szó róla (nem kötelező)', hintText: 'Miért jó? Mire figyeljünk?'),
            ),
            Wrap(
              spacing: 6,
              children: [
                for (final t in IdeaTag.values)
                  FilterChip(
                    label: Text(t.label),
                    selected: _tags.contains(t),
                    onSelected: (on) => setState(() => on ? _tags.add(t) : _tags.remove(t)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.location_on_outlined, color: AppColors.accent),
              title: Text(_place == null ? 'Helyszín (nem kötelező)' : _place!.name),
              subtitle: _place == null ? const Text('Így a közelben lakók is megtalálják.') : Text(_place!.label),
              trailing: _place == null ? const Icon(Icons.map_outlined) : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _place = null)),
              onTap: () async {
                final p = await pickIdeaPlace(context, initial: _place);
                if (p != null) setState(() => _place = p);
              },
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _busy ? null : _share, child: const Text('Megosztás mindenkivel')),
          ],
        ),
      ),
    );
  }
}
