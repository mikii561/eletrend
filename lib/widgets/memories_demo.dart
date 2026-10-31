import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Kis animált példa egy „telefonon”: a Főoldalon felbukkan egy emlék, rákoppintasz, megnyílnak a
/// közös fotók, és egy fotót nagyban is megnézel. Végtelenítve ismétlődik.
///
/// Rajzolt (nem videófájl), így minden képernyőn éles, és a téma színeit követi. Ha a rendszerben
/// ki vannak kapcsolva az animációk, egy álló képet mutat.
class MemoriesDemo extends StatelessWidget {
  const MemoriesDemo({super.key, this.height = 230});

  final double height;

  /// Egy kör hossza.
  static const loop = Duration(milliseconds: 7000);

  @override
  Widget build(BuildContext context) => _DemoPhone(
        height: height,
        loop: loop,
        label: 'Animált példa: a Főoldalon megjelenő emlékre koppintva megnyílnak a közös fotók, és egy fotó nagyban is látszik.',
        frame: (t) => _Frame(t: t),
      );
}

/// Kis animált példa: egy közös program oldalán a „Fotó” gombbal kiválasztasz pár képet,
/// beállítod, ki láthatja, feltöltöd, és megjelennek az Emlékek között.
class PhotoUploadDemo extends StatelessWidget {
  const PhotoUploadDemo({super.key, this.height = 230});

  final double height;

  static const loop = Duration(milliseconds: 9000);

  @override
  Widget build(BuildContext context) => _DemoPhone(
        height: height,
        loop: loop,
        label: 'Animált példa: a közös program Emlékek részénél a Fotó gombbal képeket választasz, '
            'beállítod, ki láthatja őket, és feltöltöd; utána a program oldalán megjelennek.',
        frame: (t) => _UploadFrame(t: t),
      );
}

/// Egy rajzolt „telefon”, benne végtelenített animációval ([frame] a 0..1 közötti időből rajzol).
class _DemoPhone extends StatefulWidget {
  const _DemoPhone({required this.height, required this.loop, required this.label, required this.frame});

  final double height;
  final Duration loop;
  final String label;
  final Widget Function(double t) frame;

  @override
  State<_DemoPhone> createState() => _DemoPhoneState();
}

class _DemoPhoneState extends State<_DemoPhone> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.loop);

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
      label: widget.label,
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
                child: AnimatedBuilder(animation: _c, builder: (context, _) => widget.frame(_c.value)),
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

/// Az „ujj”: kör, ami koppintáskor összemegy.
class _Finger extends StatelessWidget {
  const _Finger({required this.at, required this.pressed, this.opacity = 1});

  final Offset at;
  final bool pressed;
  final double opacity;

  @override
  Widget build(BuildContext context) => Positioned(
        left: at.dx - 11,
        top: at.dy - 11,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: AnimatedScale(
            scale: pressed ? 0.75 : 1,
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
      );
}

/// A feltöltés lépései: program oldala → képválasztó (3 kép) → kik láthatják → feltöltés → kész.
class _UploadFrame extends StatelessWidget {
  const _UploadFrame({required this.t});

  final double t;

  // Szakaszhatárok.
  static const _picker = 0.24, _options = 0.50, _progress = 0.68, _done = 0.80;

  /// A kiválasztott képek a rácsban, és mikor koppint rájuk.
  static const _chosen = [0, 4, 5];
  static const _chooseAt = [0.30, 0.355, 0.41];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth, h = c.maxHeight;
        final left = w * 0.08;
        final thumb = (w * 0.84 - 12) / 4;
        final stripTop = h * 0.56;
        final plusTile = Rect.fromLTWH(left, stripTop, thumb, thumb);
        final pickCell = (w - 16) / 3;
        Rect pick(int i) => Rect.fromLTWH(4 + (i % 3) * (pickCell + 4), h * 0.14 + (i ~/ 3) * (pickCell + 4), pickCell, pickCell);
        final addButton = Rect.fromLTWH(w * 0.2, h * 0.80, w * 0.6, 22);
        final uploadButton = Rect.fromLTWH(w * 0.12, h * 0.84, w * 0.76, 24);

        final sheetUp = _seg(t, _picker - 0.02, _picker + 0.04) * (1 - _seg(t, _options - 0.02, _options + 0.01));
        final optionsUp = _seg(t, _options - 0.01, _options + 0.05) * (1 - _seg(t, _progress - 0.02, _progress));
        final picked = _chooseAt.where((ct) => t > ct).length;

        // Az ujj útja.
        Offset finger;
        var pressed = false;
        if (t < _picker) {
          finger = Offset.lerp(Offset(w * 0.8, h * 0.95), plusTile.center, _seg(t, 0.05, 0.17))!;
          pressed = t > 0.18 && t < 0.23;
        } else if (t < _options) {
          var at = plusTile.center;
          for (var k = 0; k < 3; k++) {
            at = Offset.lerp(at, pick(_chosen[k]).center, _seg(t, _chooseAt[k] - 0.05, _chooseAt[k] - 0.01))!;
          }
          finger = Offset.lerp(at, addButton.center, _seg(t, 0.43, 0.46))!;
          pressed = _chooseAt.any((ct) => t > ct && t < ct + 0.02) || (t > 0.47 && t < 0.49);
        } else if (t < _progress) {
          finger = Offset.lerp(addButton.center, uploadButton.center, _seg(t, 0.56, 0.62))!;
          pressed = t > 0.63 && t < 0.66;
        } else {
          finger = Offset.lerp(uploadButton.center, Offset(w * 0.8, h * 1.05), _seg(t, 0.68, 0.76))!;
        }
        final fingerOpacity = t < 0.04 ? t * 25 : (t > 0.74 ? max(0.0, 1 - (t - 0.74) * 12) : 1.0);

        return Stack(
          children: [
            Positioned.fill(child: _EventPage(t: t, left: left, thumb: thumb, stripTop: stripTop, plusTile: plusTile)),
            if (sheetUp > 0)
              Positioned(
                left: 0,
                right: 0,
                top: h * (1 - sheetUp) + h * 0.06 * sheetUp,
                height: h,
                child: _Picker(t: t, pick: pick, addButton: addButton, picked: picked, top: h * 0.06),
              ),
            if (optionsUp > 0) Positioned.fill(child: _Options(t: t, up: optionsUp, uploadButton: uploadButton)),
            if (t >= _progress && t < _done)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, value: _seg(t, _progress, _done)),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Feltöltés: ${min(3, (_seg(t, _progress, _done - 0.01) * 3).floor() + 1)} / 3',
                              maxLines: 1,
                              style: TextStyle(fontSize: 8, color: AppColors.text),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            _Finger(at: finger, pressed: pressed, opacity: fingerOpacity),
          ],
        );
      },
    );
  }
}

/// A közös program oldala az Emlékek résszel (a végén a feltöltött képekkel).
class _EventPage extends StatelessWidget {
  const _EventPage({required this.t, required this.left, required this.thumb, required this.stripTop, required this.plusTile});

  final double t;
  final double left;
  final double thumb;
  final double stripTop;
  final Rect plusTile;

  @override
  Widget build(BuildContext context) {
    const done = _UploadFrame._done;
    final uploaded = t >= done;
    return ColoredBox(
      color: AppColors.background,
      child: Stack(
        children: [
          Positioned(
            left: left,
            right: left,
            top: 12,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.divider)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pizzaest', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.text)),
                  Text('Tegnap · Budapest', style: TextStyle(fontSize: 7, color: AppColors.textMuted)),
                ],
              ),
            ),
          ),
          Positioned(
            left: left,
            right: left,
            top: stripTop - 58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Résztvevők · 4 megy', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: AppColors.text)),
                const SizedBox(height: 4),
                _Bar(double.infinity, height: 16),
              ],
            ),
          ),
          Positioned(
            left: left,
            top: stripTop - 14,
            child: Text('Emlékek', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: AppColors.text)),
          ),
          Positioned.fromRect(
            rect: plusTile,
            child: Container(
              decoration: BoxDecoration(
                color: t > 0.18 && t < 0.23 ? AppColors.primary.withValues(alpha: 0.12) : AppColors.card,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.divider),
              ),
              child: Icon(Icons.add_photo_alternate_outlined, size: 14, color: AppColors.primary),
            ),
          ),
          if (uploaded)
            for (var k = 0; k < 3; k++)
              Positioned(
                left: left + (k + 1) * (thumb + 4),
                top: stripTop + (1 - _seg(t, done + k * 0.03, done + 0.05 + k * 0.03)) * 12,
                width: thumb,
                height: thumb,
                child: Opacity(
                  opacity: _seg(t, done + k * 0.03, done + 0.05 + k * 0.03),
                  child: _Photo(color: _photoColors[_UploadFrame._chosen[k]]),
                ),
              )
          else
            Positioned(
              left: left + thumb + 8,
              top: stripTop + thumb / 2 - 5,
              child: Text('Még nincs fotó', style: TextStyle(fontSize: 7, color: AppColors.textMuted)),
            ),
          if (t > 0.86)
            Positioned(
              left: 6,
              right: 6,
              bottom: 8,
              child: Opacity(
                opacity: _seg(t, 0.86, 0.9),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.text, borderRadius: BorderRadius.circular(6)),
                  child: Text('Feltöltve: 3 fotó.', style: TextStyle(fontSize: 8, color: AppColors.background)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A telefon képválasztója: 3×3 kép, a kiválasztottakon pipa.
class _Picker extends StatelessWidget {
  const _Picker({required this.t, required this.pick, required this.addButton, required this.picked, required this.top});

  final double t;
  final Rect Function(int i) pick;
  final Rect addButton;
  final int picked;

  /// A lap teteje a képernyőn (a [pick] és az [addButton] képernyő-koordinátákban van).
  final double top;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
      child: Stack(
        children: [
          Positioned(
            left: 8,
            top: 6,
            child: Text('Képek kiválasztása', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.text)),
          ),
          for (var i = 0; i < 9; i++)
            Positioned.fromRect(
              rect: pick(i).translate(0, -top),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Photo(color: _photoColors[i % _photoColors.length]),
                  if (_UploadFrame._chosen.contains(i) && t > _UploadFrame._chooseAt[_UploadFrame._chosen.indexOf(i)])
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        child: Icon(Icons.check, size: 9, color: AppColors.onPrimary),
                      ),
                    ),
                ],
              ),
            ),
          Positioned.fromRect(
            rect: addButton.translate(0, -top),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
              child: Text(
                'Hozzáadás ($picked)',
                style: TextStyle(fontSize: 8, color: AppColors.onPrimary, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// „Ki láthatja?” lap a feltöltés előtt.
class _Options extends StatelessWidget {
  const _Options({required this.t, required this.up, required this.uploadButton});

  final double t;
  final double up;
  final Rect uploadButton;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight;
        final shift = h * 0.6 * (1 - up);
        return ColoredBox(
          color: Colors.black.withValues(alpha: 0.35 * up),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: h * 0.40 + shift,
                bottom: -shift,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('3 fotó feltöltése', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.text)),
                      const SizedBox(height: 3),
                      Text('Ki láthatja?', style: TextStyle(fontSize: 7, color: AppColors.textMuted)),
                      for (final (label, on) in [('Mindenki a programból', true), ('Csak akik ott voltak', false)])
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(
                            children: [
                              Icon(on ? Icons.radio_button_checked : Icons.radio_button_off, size: 10, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 7, color: AppColors.text))),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          children: [
                            Expanded(child: Text('Mások is letölthetik', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 7, color: AppColors.text))),
                            Icon(Icons.toggle_on, size: 16, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: uploadButton.translate(0, shift),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t > 0.63 && t < 0.66 ? AppColors.primary.withValues(alpha: 0.8) : AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Feltöltés', style: TextStyle(fontSize: 8, color: AppColors.onPrimary, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
