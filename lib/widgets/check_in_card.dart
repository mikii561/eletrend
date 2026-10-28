import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';
import 'tag_icon.dart';

/// „Hogy vagy most?”: gyors hangulat napközben, egy koppintással. Ha 3 órán belül már
/// válaszoltál, nem kérdez újra.
class CheckInCard extends StatefulWidget {
  const CheckInCard({super.key});

  @override
  State<CheckInCard> createState() => _CheckInCardState();
}

class _CheckInCardState extends State<CheckInCard> {
  bool _thanked = false;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final last = store.lastCheckIn;
    final recent = last != null && now.difference(last.at).inHours < 3;
    // Éjjel és ha nemrég válaszolt, nem kérdezünk (kivéve a köszönetet közvetlenül utána).
    if ((recent && !_thanked) || now.hour < 7 || now.hour >= 22) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: _thanked
              ? const Text('Köszi! 👍 Napközben máskor is megkérdezem.', style: TextStyle(fontWeight: FontWeight.w700))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Hogy vagy most?', style: TextStyle(fontWeight: FontWeight.w800)),
                    Text('Egy koppintás: így látod majd, melyik napszak tesz jót.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var m = 1; m <= 5; m++)
                          IconButton(
                            tooltip: store.moodFace(m).name,
                            onPressed: () {
                              store.addCheckIn(m);
                              setState(() => _thanked = true);
                            },
                            icon: MoodFace(m, size: 34),
                          ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
