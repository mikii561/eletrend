import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';

/// Szakaszcím opcionális "Mind" gombbal.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing, this.onMore});

  final String title;
  final String? trailing;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 6, left: 2),
      child: Row(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  Text(trailing!, style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w500, fontSize: 14)),
                ],
              ],
            ),
          ),
          if (onMore != null) TextButton(onPressed: onMore, child: const Text('Mind')),
        ],
      ),
    );
  }
}

/// Üres lista helyére: nagy emoji, szöveg és opcionális gomb.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.emoji, required this.text, this.action, this.onAction});

  final String emoji;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
              child: Text(emoji, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
            if (action != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dátum "csempe": hónap rövidítve és a nap száma.
class DateBadge extends StatelessWidget {
  const DateBadge(this.date, {super.key, this.size = 56});

  final DateTime date;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: AppColors.dark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            DateFormat.MMM('hu').format(date).replaceAll('.', '').toUpperCase(),
            style: TextStyle(color: AppColors.primary, fontSize: size * 0.18, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          ),
          Text('${date.day}', style: TextStyle(color: AppColors.text, fontSize: size * 0.38, fontWeight: FontWeight.w700, height: 1.1)),
        ],
      ),
    );
  }
}

/// Kerek kezdőbetűs avatar egy névhez, névből számolt színnel.
class NameAvatar extends StatelessWidget {
  const NameAvatar(this.name, {super.key, this.radius = 16});

  final String name;
  final double radius;

  static const _colors = [
    Color(0xFF590907), Color(0xFF6B6E5D), Color(0xFF8C5A3C),
    Color(0xFF7A4E6E), Color(0xFF3F5E5A), Color(0xFFA0672A),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[name.hashCode.abs() % _colors.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        name.characters.first.toUpperCase(),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: radius * 0.85),
      ),
    );
  }
}

/// Egymásra csúsztatott avatarok (pl. meghívottak).
class AvatarStack extends StatelessWidget {
  const AvatarStack(this.names, {super.key, this.max = 4});

  final List<String> names;
  final int max;

  @override
  Widget build(BuildContext context) {
    final shown = names.take(max).toList();
    final extra = names.length - shown.length;
    return SizedBox(
      height: 32,
      width: 20.0 * shown.length + 12 + (extra > 0 ? 20 : 0),
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * 20.0,
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.card),
                padding: const EdgeInsets.all(2),
                child: NameAvatar(shown[i], radius: 14),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: shown.length * 20.0,
              child: CircleAvatar(radius: 16, backgroundColor: AppColors.card, child: Text('+$extra', style: const TextStyle(fontSize: 11))),
            ),
        ],
      ),
    );
  }
}

/// Alulról felcsúszó szövegbekérő (telefonon kényelmesebb, mint egy dialógus).
Future<String?> showTextInputSheet(BuildContext context, {required String title, String? hint, String? action}) {
  final controller = TextEditingController();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.background,
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: hint),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(action ?? 'Mentés')),
        ],
      ),
    ),
  );
}

/// Ikon halványan színezett, lekerekített négyzetben (listák elején, emoji helyett).
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.color});

  final IconData icon;

  /// Alapból a márkaszín.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: c.withValues(alpha: AppColors.dark ? 0.18 : 0.09), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 20, color: c),
    );
  }
}
