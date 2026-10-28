import 'package:flutter/material.dart';

import '../ideas.dart';
import '../theme.dart';
import 'events_screen.dart';

/// Ötletadó: véletlen programötlet, szűrhető, és egy koppintással megszervezhető.
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
  final Set<IdeaTag> _filters = {};
  late Idea? _idea = randomIdea(_filters);

  void _roll() => setState(() => _idea = randomIdea(_filters, not: _idea));

  void _toggle(IdeaTag t) {
    setState(() => _filters.contains(t) ? _filters.remove(t) : _filters.add(t));
    _roll();
  }

  @override
  Widget build(BuildContext context) {
    final idea = _idea;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Mit csináljunk? 🎲', style: theme.textTheme.titleLarge),
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
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
              child: Card(
                key: ValueKey(idea?.title),
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: idea == null
                      ? Text('Ezekre a szűrőkre nincs ötletem. Vegyél ki egyet!',
                          textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted))
                      : Column(
                          children: [
                            Text(idea.emoji, style: const TextStyle(fontSize: 64)),
                            const SizedBox(height: 8),
                            Text(idea.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            Text(idea.text, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
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
                Expanded(
                  child: FilledButton(
                    onPressed: idea == null
                        ? null
                        : () {
                            final navigator = Navigator.of(context);
                            navigator.pop();
                            navigator.push(MaterialPageRoute(
                              builder: (_) => EventEditor(initialTitle: '${idea.emoji} ${idea.title}'),
                            ));
                          },
                    child: const Text('Ezt szervezem!'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
