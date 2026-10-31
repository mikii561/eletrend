import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Kis animált példa egy „telefonon”: a Főoldalon felbukkan egy emlék, rákoppintasz, megnyílnak a
/// közös fotók, és egy fotót nagyban is megnézel. Végtelenítve ismétlődik.
///
/// Rajzolt (nem videófájl), így minden képernyőn éles, és a téma színeit követi. Ha a rendszerben
/// ki vannak kapcsolva az animációk, egy álló képet mutat.
class MemoriesDemo extends StatefulWidget {
  const MemoriesDemo({super.key, this.height = 230});

  final double height;

  /// Egy kör hossza.
  static const loop = Duration(milliseconds: 7000);

  @override
  State<MemoriesDemo> createState() => _MemoriesDemoState();
}

class _MemoriesDemoState extends State<MemoriesDemo> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: MemoriesDemo.loop);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c
        ..stop()
        ..value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Animált példa: a Főoldalon megjelenő emlékre koppintva megnyílnak a közös fotók, és egy fotó nagyban is látszik.',
      child: SizedBox(
        height: widget.height,
        child: Center(
          child: AspectRatio(
            aspectRatio: 0.62,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: const Color(0xFF1E1716), borderRadius: BorderRadius.circular(18)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: AnimatedBuilder(animation: _c, builder: (context, _) => _Frame(t: _c.value)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A színek a minta-fotókhoz (tó, naplemente, erdő…).
const _photoColors = [Color(0xFF3A6E8C), Color(0xFFC8964F), Color(0xFF5A7846), Color(0xFF8C5A3C), Color(0xFF6E3B5E), Color(0xFF4F5D73)];

/// [a]–[b] közötti szakasz előrehaladása 0..1-re vetítve, lágyítva.
double _seg(double t, double a, double b) => Curves.easeInOut.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

class _Frame extends StatelessWidget {
  const _Frame({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth, h = c.maxHeight;
        // Szakaszok: 0–0,32 Főoldal, 0,32–0,64 galéria, 0,64–1 nagy fotó.
        final toGallery = _seg(t, 0.30, 0.36);
        final toPhoto = _seg(t, 0.62, 0.72);
        final cardRect = Rect.fromLTWH(w * 0.08, h * 0.40, w * 0.84, h * 0.38);
        final cell = (w * 0.84 - 8) / 3;
        final secondCell = Rect.fromLTWH(w * 0.08 + cell + 4, h * 0.38, cell, cell);

        // Az „ujj”: oda megy, ahová koppintunk, és koppintáskor összemegy.
        Offset finger;
        double press = 0;
        if (t < 0.32) {
          finger = Offset.lerp(Offset(w * 0.85, h * 0.95), cardRect.center, _seg(t, 0.06, 0.22))!;
          press = t > 0.23 && t < 0.29 ? 1 : 0;
        } else if (t < 0.64) {
          finger = Offset.lerp(cardRect.center, secondCell.center, _seg(t, 0.40, 0.54))!;
          press = t > 0.55 && t < 0.61 ? 1 : 0;
        } else {
          finger = Offset.lerp(secondCell.center, Offset(w * 0.75, h * 0.98), _seg(t, 0.66, 0.78))!;
        }
        final fingerOpacity = t > 0.80 ? max(0.0, 1 - (t - 0.80) * 10) : (t < 0.04 ? t * 25 : 1.0);

        return Stack(
          children: [
            // 1. Főoldal az emlék-kártyával
            Positioned.fill(child: _Home(cardRect: cardRect, highlight: press > 0 && t < 0.32)),
            // 2. Galéria (jobbról becsúszik)
            if (toGallery > 0)
              Positioned(
                left: w * (1 - toGallery),
                top: 0,
                width: w,
                height: h,
                child: _Gallery(cell: cell, top: h * 0.38, highlight: press > 0 && t > 0.32 ? 1 : -1),
              ),
            // 3. Nagy fotó (a rácsból nő ki)
            if (toPhoto > 0)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: toPhoto),
                  child: Stack(
                    children: [
                      Positioned.fromRect(
                        rect: Rect.lerp(secondCell, Rect.fromLTWH(0, h * 0.22, w, w * 0.8), toPhoto)!,
                        child: _Photo(color: _photoColors[1], radius: 6 * (1 - toPhoto)),
                      ),
                      Positioned(
                        left: 10,
                        right: 10,
                        bottom: 10,
                        child: Opacity(
                          opacity: _seg(t, 0.72, 0.78),
                          child: Row(
                            children: [
                              const Expanded(child: Text('Anna · 1 éve', style: TextStyle(color: Colors.white70, fontSize: 9))),
                              Icon(Icons.download_outlined, color: Colors.white.withValues(alpha: 0.9), size: 12),
                              const Text(' Letöltés', style: TextStyle(color: Colors.white, fontSize: 9)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Az ujj
            Positioned(
              left: finger.dx - 11,
              top: finger.dy - 11,
              child: Opacity(
                opacity: fingerOpacity.clamp(0.0, 1.0),
                child: AnimatedScale(
                  scale: press > 0 ? 0.75 : 1,
                  duration: const Duration(milliseconds: 120),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black.withValues(alpha: 0.35), width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar(this.width, {this.height = 6});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(3)),
      );
}

class _Photo extends StatelessWidget {
  const _Photo({required this.color, this.radius = 4});

  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: ColoredBox(
          color: color,
          child: LayoutBuilder(
            builder: (context, c) => Stack(
              children: [
                // Egyszerű „táj”: nap és domb.
                Positioned(
                  left: c.maxWidth * 0.55,
                  top: c.maxHeight * 0.18,
                  width: c.maxWidth * 0.22,
                  height: c.maxWidth * 0.22,
                  child: const DecoratedBox(decoration: BoxDecoration(color: Color(0xFFF4E9DA), shape: BoxShape.circle)),
                ),
                Positioned(
                  left: -c.maxWidth * 0.2,
                  right: -c.maxWidth * 0.2,
                  bottom: -c.maxHeight * 0.45,
                  height: c.maxHeight * 0.8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.18), shape: BoxShape.circle),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _Home extends StatelessWidget {
  const _Home({required this.cardRect, required this.highlight});

  final Rect cardRect;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Stack(
        children: [
          Positioned(
            left: cardRect.left,
            top: 14,
            right: cardRect.left,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Bar(40, height: 4),
                const SizedBox(height: 4),
                Text('Szia, Gabi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text)),
                const SizedBox(height: 8),
                Container(
                  height: 26,
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.divider)),
                ),
              ],
            ),
          ),
          Positioned(
            left: cardRect.left,
            top: cardRect.top - 14,
            child: Text('Emlékek · ma 1 éve', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: AppColors.text)),
          ),
          Positioned.fromRect(
            rect: cardRect,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: highlight ? AppColors.primary.withValues(alpha: 0.12) : AppColors.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Balatoni hétvége', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.text)),
                  Text('2025. okt. 31. · Balatonfüred', style: TextStyle(fontSize: 7, color: AppColors.textMuted)),
                  const SizedBox(height: 5),
                  Expanded(
                    child: Row(
                      children: [
                        for (var i = 0; i < 3; i++) ...[
                          Expanded(child: _Photo(color: _photoColors[i])),
                          if (i < 2) const SizedBox(width: 4),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: cardRect.left,
            right: cardRect.left,
            top: cardRect.bottom + 10,
            child: Column(children: [_Bar(double.infinity, height: 20), const SizedBox(height: 6), _Bar(double.infinity, height: 20)]),
          ),
        ],
      ),
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({required this.cell, required this.top, required this.highlight});

  final double cell;
  final double top;

  /// Melyik fotó van épp lenyomva (-1: egyik sem).
  final int highlight;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: LayoutBuilder(
        builder: (context, c) {
          final left = c.maxWidth * 0.08;
          return Stack(
            children: [
              Positioned(
                left: left,
                top: 14,
                child: Text('Emlékek', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text)),
              ),
              Positioned(
                left: left,
                right: left,
                top: 34,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.divider)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Balatoni hétvége', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.text)),
                      Text('1 éve · Balatonfüred', style: TextStyle(fontSize: 7, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ),
              for (var i = 0; i < 6; i++)
                Positioned(
                  left: left + (i % 3) * (cell + 4),
                  top: top + (i ~/ 3) * (cell + 4),
                  width: cell,
                  height: cell,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: highlight == 1 && i == 1 ? 0.6 : 1,
                    child: _Photo(color: _photoColors[i]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
