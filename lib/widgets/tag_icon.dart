import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';

/// Egy hangulatcímke ikonja: a saját kép, vagy ha nincs, az emoji.
class TagIcon extends StatelessWidget {
  const TagIcon(this.tag, {super.key, this.size = 18, this.circle = false});

  final MoodTag tag;
  final double size;

  /// Kerek kép (hangulatarcokhoz), különben lekerekített négyzet.
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final bytes = tag.imageBytes;
    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(circle ? size / 2 : size * 0.3),
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          // Ha a kép valamiért sérült, legalább az emoji látsszon.
          errorBuilder: (_, _, _) => _emoji(),
        ),
      );
    }
    return _emoji();
  }

  Widget _emoji() => SizedBox(
        width: size,
        height: size,
        child: Center(child: Text(tag.emoji, style: TextStyle(fontSize: size * 0.8, height: 1))),
      );
}

/// Ikon + név egy sorban (chipekhez, címkékhez).
class TagLabel extends StatelessWidget {
  const TagLabel(this.tag, {super.key, this.size = 18, this.style});

  final MoodTag tag;
  final double size;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TagIcon(tag, size: size),
        const SizedBox(width: 5),
        Flexible(child: Text(tag.name, overflow: TextOverflow.ellipsis, style: style)),
      ],
    );
  }
}

/// Az 1–5 hangulat arca: a felhasználó saját emojija vagy képe.
class MoodFace extends StatelessWidget {
  const MoodFace(this.mood, {super.key, this.size = 22});

  final int mood;
  final double size;

  @override
  Widget build(BuildContext context) => TagIcon(StoreScope.of(context).moodFace(mood), size: size, circle: true);
}
