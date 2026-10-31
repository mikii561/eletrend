import 'dart:convert';

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
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    trailing!,
                    style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w500, fontSize: 14),
                  ),
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
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
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
            style: TextStyle(
              color: AppColors.primary,
              fontSize: size * 0.18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            '${date.day}',
            style: TextStyle(color: AppColors.text, fontSize: size * 0.38, fontWeight: FontWeight.w700, height: 1.1),
          ),
        ],
      ),
    );
  }
}

/// Kerek kezdőbetűs avatar egy névhez, névből számolt színnel.
class NameAvatar extends StatelessWidget {
  const NameAvatar(this.name, {super.key, this.radius = 16, this.photo = ''});

  final String name;
  final double radius;

  /// Profilkép (base64 JPEG); ha van, a kezdőbetű helyett ez látszik.
  final String photo;

  static const _colors = [
    Color(0xFF590907),
    Color(0xFF6B6E5D),
    Color(0xFF8C5A3C),
    Color(0xFF7A4E6E),
    Color(0xFF3F5E5A),
    Color(0xFFA0672A),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[name.hashCode.abs() % _colors.length];
    if (photo.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: color,
        backgroundImage: ResizeImage(MemoryImage(base64Decode(photo)), width: (radius * 4).round()),
        onBackgroundImageError: (_, _) {},
      );
    }
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
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.card,
                child: Text('+$extra', style: const TextStyle(fontSize: 11)),
              ),
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
      decoration: BoxDecoration(
        color: c.withValues(alpha: AppColors.dark ? 0.18 : 0.09),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: c),
    );
  }
}

/// Kis, színes címke (pl. „Legjobb”, „Közös”, „Lejárt”).
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color, this.icon});

  final String text;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: AppColors.dark ? 0.22 : 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: c), const SizedBox(width: 3)],
          Text(
            text,
            style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Megerősítő ablak („Biztosan törlöd?”). Igazat ad, ha a felhasználó megerősítette.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  String? text,
  String action = 'Igen',
  bool danger = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: text == null ? null : Text(text),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Mégse')),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white)
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Betöltés közben.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.text});

  final String? text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
        if (text != null) ...[const SizedBox(height: 12), Text(text!, style: TextStyle(color: AppColors.textMuted))],
      ],
    ),
  );
}

/// Hiba (pl. nincs internet), opcionális újrapróbálással.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(color: AppColors.textMuted)),
          ),
          if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Újra')),
        ],
      ),
    ),
  );
}

/// Kategória színes jelölője (kis kör vagy függőleges csík).
class CategoryDot extends StatelessWidget {
  const CategoryDot(this.color, {super.key, this.size = 10});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// Egy beállítás-sor ikonnal (Profil és aloldalai).
class SettingsTile extends StatelessWidget {
  const SettingsTile({super.key, required this.icon, required this.title, this.subtitle, this.onTap, this.trailing});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: IconTile(icon),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right)),
    onTap: onTap,
  );
}

/// Szám egy ikon sarkán (pl. olvasatlan bökések). 0-nál nem látszik; 99 fölött „99+”.
/// Megjelenéskor és változáskor finoman „bepattan”.
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count, required this.child, this.label});

  final int count;
  final Widget child;

  /// Felolvasáshoz, pl. „olvasatlan bökés”.
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: count > 0 && label != null ? '$count $label' : null,
      child: Badge(
        isLabelVisible: count > 0,
        backgroundColor: AppColors.danger,
        textColor: Colors.white,
        label: TweenAnimationBuilder<double>(
          key: ValueKey(count),
          tween: Tween(begin: 0.6, end: 1),
          duration: MediaQuery.maybeDisableAnimationsOf(context) == true
              ? Duration.zero
              : const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
          child: Text(count > 99 ? '99+' : '$count'),
        ),
        child: child,
      ),
    );
  }
}
