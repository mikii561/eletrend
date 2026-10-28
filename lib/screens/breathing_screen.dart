import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';

/// Egy légzésminta: szakaszok (felirat, másodperc, a kör mérete a végén 0–1).
class BreathPattern {
  const BreathPattern(this.name, this.text, this.phases);

  final String name;
  final String text;
  final List<(String, int, double)> phases;

  int get cycleSeconds => phases.fold(0, (s, p) => s + p.$2);
}

const breathPatterns = [
  BreathPattern('Nyugtató', '4 mp be, 4 tartás, 6 ki', [('Belégzés', 4, 1), ('Tartsd', 4, 1), ('Kilégzés', 6, 0)]),
  BreathPattern('Alvás előtt', '4 be, 7 tartás, 8 ki', [('Belégzés', 4, 1), ('Tartsd', 7, 1), ('Kilégzés', 8, 0)]),
  BreathPattern('Doboz', '4–4–4–4, fókuszhoz', [('Belégzés', 4, 1), ('Tartsd', 4, 1), ('Kilégzés', 4, 0), ('Tartsd', 4, 0)]),
];

/// Légzőgyakorlat / meditáció időzítő. A végén kipipálhatja a hozzá választott célt.
class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  BreathPattern _pattern = breathPatterns.first;
  int _minutes = 3;
  Duration _elapsed = Duration.zero;
  bool _running = false;
  bool _finished = false;
  String? _habitId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ha van meditáció/légzés jellegű cél, azt ajánljuk fel kipipálásra.
    _habitId ??= StoreScope.of(context)
        .habits
        .where((h) => RegExp('medit|légz|legz|nyug|jóga|joga', caseSensitive: false).hasMatch(h.name))
        .firstOrNull
        ?.id;
  }

  void _tick(Duration elapsed) {
    setState(() => _elapsed = elapsed);
    if (elapsed >= Duration(minutes: _minutes)) _finish();
  }

  void _start() {
    setState(() {
      _running = true;
      _finished = false;
      _elapsed = Duration.zero;
    });
    _ticker.start();
  }

  void _stop() {
    _ticker.stop();
    setState(() => _running = false);
  }

  void _finish() {
    _ticker.stop();
    final store = StoreScope.of(context);
    final habit = store.habits.where((h) => h.id == _habitId).firstOrNull;
    if (habit != null && !habit.isDoneOn(DateTime.now())) store.toggleHabit(habit);
    setState(() {
      _running = false;
      _finished = true;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// Hol tart a légzés: a szakasz neve, a hátralévő másodperc és a kör mérete (0–1).
  (String, int, double) _phase() {
    final cycle = _pattern.cycleSeconds * 1000;
    var t = _elapsed.inMilliseconds % cycle;
    var from = _pattern.phases.last.$3;
    for (final (label, seconds, to) in _pattern.phases) {
      final ms = seconds * 1000;
      if (t < ms) {
        final p = Curves.easeInOut.transform(t / ms);
        return (label, ((ms - t) / 1000).ceil(), from + (to - from) * p);
      }
      t -= ms;
      from = to;
    }
    return (_pattern.phases.first.$1, _pattern.phases.first.$2, 0);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final (label, secondsLeft, size) = _phase();
    final left = Duration(minutes: _minutes) - _elapsed;
    final habit = store.habits.where((h) => h.id == _habitId).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Légzőgyakorlat')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          SizedBox(
            height: 300,
            child: Center(
              child: _finished
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🧘', style: TextStyle(fontSize: 80)),
                        Text('Kész! Szép munka.', style: Theme.of(context).textTheme.titleLarge),
                        if (habit != null) Text('„${habit.name}” kipipálva ✅', style: TextStyle(color: AppColors.textMuted)),
                      ],
                    )
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 120 + 140 * (_running ? size : 0.3),
                          height: 120 + 140 * (_running ? size : 0.3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [
                              AppColors.primary.withValues(alpha: 0.55),
                              AppColors.accent.withValues(alpha: 0.35),
                            ]),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_running ? label : 'Kezdjük?',
                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
                            if (_running)
                              Text('$secondsLeft', style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
          if (_running)
            Text(
              'Még ${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')}',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700),
            ),
          const SizedBox(height: 12),
          if (!_running) ...[
            Text('Minta', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            for (final p in breathPatterns)
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                color: p == _pattern ? AppColors.primary.withValues(alpha: 0.15) : null,
                child: ListTile(
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(p.text),
                  trailing: p == _pattern ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                  onTap: () => setState(() => _pattern = p),
                ),
              ),
            const SizedBox(height: 10),
            Text('Időtartam', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final m in [1, 3, 5, 10])
                  ChoiceChip(label: Text('$m perc'), selected: _minutes == m, onSelected: (_) => setState(() => _minutes = m)),
              ],
            ),
            if (store.habits.isNotEmpty) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                initialValue: _habitId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'A végén kipipálja ezt a célt'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Egyiket sem')),
                  for (final Habit h in store.habits) DropdownMenuItem(value: h.id, child: Text(h.name, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _habitId = v),
              ),
            ],
          ],
          const SizedBox(height: 16),
          _running
              ? OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: _stop,
                  child: const Text('Leállítás'),
                )
              : FilledButton(onPressed: _start, child: Text(_finished ? 'Még egy kör' : 'Indítás')),
          const SizedBox(height: 8),
          Text('Tipp: ülj kényelmesen, és csak kövesd a kört. ${max(1, _pattern.cycleSeconds)} mp egy légzés.',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}
