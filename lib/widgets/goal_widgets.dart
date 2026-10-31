import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// Nagy, kerek pipa gomb a célokhoz.
class CheckCircle extends StatelessWidget {
  const CheckCircle({super.key, required this.done, required this.onTap, this.size = 36});

  final bool done;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: done ? AppColors.headerGradient : null,
          border: done ? null : Border.all(color: AppColors.divider, width: 2.5),
        ),
        child: done ? Icon(Icons.check_rounded, color: AppColors.onPrimary, size: size * 0.6) : null,
      ),
    );
  }
}

class StreakChip extends StatelessWidget {
  const StreakChip(this.days, {super.key, this.unit = 'nap'});

  final int days;

  /// „nap” vagy (heti célnál) „hét”.
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: days > 0 ? AppColors.accent.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded, size: 16, color: days > 0 ? AppColors.accent : AppColors.textMuted),
          const SizedBox(width: 2),
          Text(
            unit == 'nap' ? '$days' : '$days $unit',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: days > 0 ? AppColors.accent : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// A cél mai állása kiíráshoz: „3/8 pohár”, „2/3 ezen a héten”; egyszerű napi célnál null.
String? habitProgress(Habit h, DateTime day) {
  final parts = [
    if (h.isCounted) '${h.countOn(day)}/${h.target}${h.unit.isEmpty ? '' : ' ${h.unit}'}',
    if (h.isWeekly) '${h.doneInWeek(day)}/${h.perWeek} ezen a héten',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}
