import 'package:flutter/material.dart';

import '../badges.dart';
import '../store.dart';
import '../theme.dart';

/// Jelvények: a megszerzettek színesen, a többi halványan, a feltételükkel.
class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final earned = earnedBadges(StoreScope.of(context));
    return Scaffold(
      appBar: AppBar(title: Text('Jelvények (${earned.length}/${achievements.length})')),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.72,
        children: [
          for (final a in achievements)
            Card(
              margin: EdgeInsets.zero,
              color: earned.contains(a.id) ? AppColors.accent.withValues(alpha: 0.15) : null,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Opacity(
                  opacity: earned.contains(a.id) ? 1 : 0.35,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(a.emoji, style: const TextStyle(fontSize: 36)),
                      const SizedBox(height: 6),
                      Text(a.title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(a.text, textAlign: TextAlign.center, maxLines: 4, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Új jelvény ünneplése.
Future<void> showBadgeEarned(BuildContext context, Achievement a, {int more = 0}) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 32)),
            Text(a.emoji, style: const TextStyle(fontSize: 72)),
            const SizedBox(height: 8),
            Text('Új jelvény: ${a.title}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(a.text, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
            if (more > 0) ...[
              const SizedBox(height: 8),
              Text('…és még $more másik!', style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BadgesScreen()));
            },
            child: const Text('Összes jelvény'),
          ),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Szuper!')),
        ],
      ),
    );
