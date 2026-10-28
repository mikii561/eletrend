import 'dart:math';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../community.dart';
import '../geocoding.dart';
import '../ideas.dart';
import '../store.dart';
import '../theme.dart';
import 'community_screen.dart';
import 'events_screen.dart';

/// Ötletadó: véletlen programötlet a beépítettekből vagy a felhasználók ajánlásaiból
/// (rendezve és hely szerint szűrve), egy koppintással megszervezhető.
Future<void> showIdeaSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _IdeaSheet(),
    );

class _IdeaSheet extends StatefulWidget {
  const _IdeaSheet();

  @override
  State<_IdeaSheet> createState() => _IdeaSheetState();
}

class _IdeaSheetState extends State<_IdeaSheet> {
  final _random = Random();
  final Set<IdeaTag> _filters = {};
  bool _community = false;

  // Beépített
  late Idea? _idea = randomIdea(_filters);

  // Közösségi
  Future<CommunityData>? _data;
  final _communityFilter = IdeaFilter();
  CommunityIdea? _pick;

  /// A közösségi ötletek közül a szűrésnek megfelelő legjobb 20-ból választunk.
  List<CommunityIdea> _pool(CommunityData d) {
    final store = StoreScope.of(context);
    return _communityFilter
        .apply(d, store.homePlace)
        .where((i) => i.tags.containsAll(_filters))
        .take(20)
        .toList();
  }

  void _rollCommunity(CommunityData d) {
    final pool = _pool(d).where((i) => i != _pick).toList();
    final all = _pool(d);
    setState(() => _pick = pool.isEmpty ? all.firstOrNull : pool[_random.nextInt(pool.length)]);
  }

  void _roll() {
    if (_community) {
      _data?.then(_rollCommunity);
    } else {
      setState(() => _idea = randomIdea(_filters, not: _idea));
    }
  }

  void _toggle(IdeaTag t) {
    setState(() => _filters.contains(t) ? _filters.remove(t) : _filters.add(t));
    _roll();
  }

  void _organize({required String title, Place? place}) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute(builder: (_) => EventEditor(initialTitle: title, initialPlace: place)));
  }

  Widget _card(Widget child, Object? key) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
        child: Card(
          key: ValueKey(key),
          margin: EdgeInsets.zero,
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16), child: child),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Mit csináljunk?', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Beépített ötletek')),
                ButtonSegment(value: true, label: Text('Felhasználók ajánlják')),
              ],
              selected: {_community},
              onSelectionChanged: (s) {
                setState(() {
                  _community = s.first;
                  _data ??= _community ? CommunityData.load() : null;
                });
                _roll();
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in IdeaTag.values)
                  FilterChip(
                    label: Text(t.label),
                    showCheckmark: false,
                    selected: _filters.contains(t),
                    selectedColor: AppColors.primary.withValues(alpha: 0.18),
                    onSelected: (_) => _toggle(t),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (!_community) ..._builtIn(theme) else _communityPart(theme),
          ],
        ),
      ),
    );
  }

  List<Widget> _builtIn(ThemeData theme) {
    final idea = _idea;
    return [
      _card(
        idea == null
            ? Text('Ezekre a szűrőkre nincs ötletem. Vegyél ki egyet!', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted))
            : Column(children: [
                Text(idea.emoji, style: const TextStyle(fontSize: 64)),
                const SizedBox(height: 8),
                Text(idea.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(idea.text, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
              ]),
        idea?.title,
      ),
      const SizedBox(height: 16),
      _buttons(onOrganize: idea == null ? null : () => _organize(title: '${idea.emoji} ${idea.title}')),
    ];
  }

  Widget _communityPart(ThemeData theme) {
    return FutureBuilder<CommunityData>(
      future: _data,
      builder: (context, snap) {
        if (snap.hasError) return Text('Nem sikerült betölteni. Van internet? (${snap.error})');
        final data = snap.data;
        if (data == null) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
        // Első betöltés után azonnal dobunk egyet.
        if (_pick == null && _pool(data).isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _rollCommunity(data));
        final pick = _pick != null && _pool(data).contains(_pick) ? _pick : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IdeaFilterBar(
              filter: _communityFilter,
              data: data,
              onChanged: () {
                setState(() => _pick = null);
                _rollCommunity(data);
              },
            ),
            const SizedBox(height: 12),
            _card(
              pick == null
                  ? Text(
                      data.ideas.isEmpty
                          ? 'Még senki nem osztott meg ötletet. Legyél te az első!'
                          : 'Erre a szűrésre nincs ötlet. Próbálj tágabb helyet vagy más rendezést.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
                    )
                  : Column(children: [
                      Text(pick.emoji, style: const TextStyle(fontSize: 64)),
                      const SizedBox(height: 8),
                      Text(pick.title,
                          textAlign: TextAlign.center, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                      if (pick.text.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(pick.text, textAlign: TextAlign.center),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        [if (pick.place.name.isNotEmpty) '📍 ${pick.place.name}', 'ajánlotta: ${pick.authorName}', scoreText(data.scores[pick.id])]
                            .join('\n'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ]),
              pick?.id,
            ),
            const SizedBox(height: 16),
            _buttons(
              onOrganize: pick == null
                  ? null
                  : () => _organize(
                        title: '${pick.emoji} ${pick.title}',
                        place: pick.place.hasPoint ? Place(name: pick.place.name, point: LatLng(pick.place.lat!, pick.place.lng!)) : null,
                      ),
            ),
            TextButton(
              onPressed: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.push(MaterialPageRoute(builder: (_) => const CommunityIdeasScreen()));
              },
              child: const Text('Összes közösségi ötlet, értékelés, megosztás →'),
            ),
          ],
        );
      },
    );
  }

  Widget _buttons({required VoidCallback? onOrganize}) => Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: _roll,
              icon: const Icon(Icons.casino_outlined),
              label: const Text('Másikat'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: FilledButton(onPressed: onOrganize, child: const Text('Ezt szervezem!'))),
        ],
      );
}
