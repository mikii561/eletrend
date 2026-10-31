import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';
import 'memories_demo.dart';
import 'motion.dart';

/// A bemutató lépései által kiemelt elemek. Egyszerre csak egy app fut, ezért elég közös kulcs.
class TourKeys {
  static final navBar = GlobalKey(debugLabel: 'tour-nav');
  static final status = GlobalKey(debugLabel: 'tour-status');
  static final quickActions = GlobalKey(debugLabel: 'tour-quick');
}

/// Egy lépés: mit emelünk ki (egy elemet, az alsó menü egy fülét, vagy semmit), és mit mondunk róla.
class TourStep {
  const TourStep({this.target, this.navSlot, required this.icon, required this.title, required this.text, this.demo});

  final GlobalKey? target;

  /// Az alsó menü hányadik helye (0–4), ha azt emeljük ki.
  final int? navSlot;
  final IconData icon;
  final String title;
  final String text;

  /// Animált példa a szöveg alatt (pl. hogyan kell megnézni egy emléket).
  final Widget? demo;
}

/// Az app bemutatója a Főoldalon.
final appTourSteps = <TourStep>[
  TourStep(
    icon: Icons.waving_hand_outlined,
    title: 'Üdv a LIFEUP-ban!',
    text: 'Egy perc alatt megmutatom, mi hol van. Bármikor kiléphetsz, és a Profilban újra elindíthatod.',
  ),
  TourStep(
    navSlot: 0,
    icon: Icons.home_outlined,
    title: 'Főoldal',
    text: 'A napod egy pillantásra: a következő program, a mai beosztás, a teendők, a célok és hogy ki ér rá.',
  ),
  TourStep(
    target: TourKeys.status,
    icon: Icons.circle_outlined,
    title: 'Az állapotod',
    text: 'Szabad, elfoglalt, nyitott programra vagy ne zavarj. Csak akkor látják a barátaid, ha engeded.',
  ),
  TourStep(
    target: TourKeys.quickActions,
    icon: Icons.bolt_outlined,
    title: 'Gyors gombok',
    text: 'Új bejegyzés, feladat, vagy közös időpont keresése a barátaiddal, egy koppintással.',
  ),
  TourStep(
    navSlot: 1,
    icon: Icons.calendar_month_outlined,
    title: 'Naptár',
    text: 'Nap, hét, hónap és lista nézet. Egy üres időpontra koppintva ott kezdődik az új bejegyzés.',
  ),
  TourStep(
    navSlot: 2,
    icon: Icons.add,
    title: 'Létrehozás',
    text: 'Innen indul minden új dolog: bejegyzés, feladat, közös program, közös időpont, cél, kihívás.',
  ),
  TourStep(
    navSlot: 3,
    icon: Icons.people_alt_outlined,
    title: 'Barátok',
    text: 'Add meg a barátkódokat, nézd meg, ki mikor ér rá, szervezz közös programot, vagy bökj meg valakit.',
  ),
  const TourStep(
    icon: Icons.add_photo_alternate_outlined,
    title: 'Közös fotók',
    text: 'Egy közös program után a program oldalán, az Emlékek résznél tölthettek fel fotókat. '
        'Te döntöd el, ki láthatja és letöltheti őket. Így megy:',
    demo: PhotoUploadDemo(),
  ),
  const TourStep(
    icon: Icons.photo_library_outlined,
    title: 'Emlékek',
    text: 'Később az app emlékként visszahozza a Főoldalon: mi volt, mikor és hol, a közös képekkel. Így néz ki:',
    demo: MemoriesDemo(),
  ),
  TourStep(
    navSlot: 4,
    icon: Icons.person_outline,
    title: 'Profil',
    text: 'Célok és kihívások, adatvédelem, értesítések, és a Főoldal testreszabása. Jó szórakozást!',
  ),
];

/// Elindítja a bemutatót a [context] Overlay-ében. Az [onDone] a végén vagy kihagyáskor fut le.
void showAppTour(BuildContext context, List<TourStep> steps, {required VoidCallback onDone}) {
  final overlay = Overlay.of(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Tour(
      steps: steps,
      onDone: () {
        entry.remove();
        onDone();
      },
    ),
  );
  overlay.insert(entry);
}

class _Tour extends StatefulWidget {
  const _Tour({required this.steps, required this.onDone});

  final List<TourStep> steps;
  final VoidCallback onDone;

  @override
  State<_Tour> createState() => _TourState();
}

class _TourState extends State<_Tour> {
  int _i = 0;

  /// Bezáráskor előbb elhalványul, és csak utána tűnik el.
  bool _closing = false;

  void _next() => _i + 1 >= widget.steps.length ? _close() : setState(() => _i++);

  Future<void> _close() async {
    if (_closing) return;
    setState(() => _closing = true);
    await Future<void>.delayed(Motion.of(context, Motion.medium));
    widget.onDone();
  }

  /// A kiemelt elem helye az overlay-en belül (null, ha nincs vagy épp nem látszik).
  Rect? _targetRect(BuildContext context) {
    final step = widget.steps[_i];
    final key = step.navSlot != null ? TourKeys.navBar : step.target;
    final box = key?.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize || overlayBox == null) return null;
    final topLeft = overlayBox.globalToLocal(box.localToGlobal(Offset.zero));
    final slot = step.navSlot;
    if (slot == null) return (topLeft & box.size).inflate(6);
    // Az alsó menü öt egyforma részre oszlik.
    final w = box.size.width / 5;
    return Rect.fromLTWH(topLeft.dx + slot * w, topLeft.dy, w, box.size.height).deflate(4);
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_i];
    final last = _i + 1 == widget.steps.length;
    final medium = Motion.of(context, Motion.medium);
    return LayoutBuilder(
      builder: (context, c) {
        final hole = _targetRect(context);
        final size = Size(c.maxWidth, c.maxHeight);
        // Kiemelés nélküli lépésnél a „lyuk” a képernyő közepére zsugorodik, így onnan nyílik ki.
        final target = hole ?? Rect.fromCenter(center: size.center(Offset.zero), width: 0, height: 0);
        // A kártya a kiemelés alá kerül, ha felül van; fölé, ha alul; középre, ha nincs kiemelés.
        final below = hole != null && hole.center.dy < size.height / 2;
        final card = _TourCard(
          step: step,
          index: _i,
          count: widget.steps.length,
          last: last,
          onNext: _next,
          onSkip: _close,
        );
        // Egy kártya van, ami a kiemeléssel együtt csúszik: a helyét minden képkockán a kiemelés
        // (animált) helyéből és a kártya (animált) magasságából számoljuk. A „fölötte/alatta”
        // váltás is folyamatos (0 = fölötte, 1 = alatta, 0,5 = középen).
        final slow = Motion.of(context, Motion.slow);
        return TweenAnimationBuilder<double>(
          // Megjelenéskor beúszik, bezáráskor elhalványul.
          tween: Tween(begin: 0, end: _closing ? 0 : 1),
          duration: medium,
          curve: Motion.curve,
          builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
          child: Material(
            type: MaterialType.transparency,
            child: TweenAnimationBuilder<Rect?>(
              tween: RectTween(end: target),
              duration: slow,
              curve: Motion.emphasized,
              builder: (context, rect, _) => TweenAnimationBuilder<double>(
                tween: Tween(end: hole == null ? 0.5 : (below ? 1.0 : 0.0)),
                duration: slow,
                curve: Motion.emphasized,
                builder: (context, side, _) {
                  final r = rect ?? target;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _next,
                          child: CustomPaint(
                            painter: _HolePainter(hole: r.width < 2 ? null : r, color: Colors.black.withValues(alpha: 0.6)),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: CustomSingleChildLayout(delegate: _CardPlacer(hole: r, side: side), child: card),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A kártya helye: a kiemelés alatt ([side] = 1), fölött (0), vagy köztes értéknél a kettő
/// között (középső lépésnél a kiemelés egy pont a képernyő közepén, így a kártya középre kerül).
class _CardPlacer extends SingleChildLayoutDelegate {
  _CardPlacer({required this.hole, required this.side});

  final Rect hole;
  final double side;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(minWidth: 0, maxWidth: min(constraints.maxWidth - 32, 420), maxHeight: constraints.maxHeight - 24);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final above = hole.top - 12 - childSize.height;
    final under = hole.bottom + 12;
    final top = (above + (under - above) * side).clamp(12.0, max(12.0, size.height - childSize.height - 12)).toDouble();
    return Offset((size.width - childSize.width) / 2, top);
  }

  @override
  bool shouldRelayout(_CardPlacer old) => old.hole != hole || old.side != side;
}

class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.step,
    required this.index,
    required this.count,
    required this.last,
    required this.onNext,
    required this.onSkip,
  });

  final TourStep step;
  final int index;
  final int count;
  final bool last;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final medium = Motion.of(context, Motion.medium);
    // A kártya kerete és a gombok helyben maradnak; csak a tartalom úszik át, a méret pedig
    // lágyan igazodik az új tartalomhoz.
    final content = Column(
      key: ValueKey(index),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: AppColors.dark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(Space.radiusSmall),
              ),
              child: Icon(step.icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(step.title, style: Theme.of(context).textTheme.titleLarge)),
            Text('${index + 1}/$count', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(width: 8),
          ],
        ),
        const SizedBox(height: 10),
        Padding(padding: const EdgeInsets.only(right: 8), child: Text(step.text, style: const TextStyle(height: 1.4))),
        if (step.demo != null) ...[const SizedBox(height: 12), step.demo!],
      ],
    );
    return Card(
      margin: EdgeInsets.zero,
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: Motion.of(context, Motion.slow),
              curve: Motion.emphasized,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: medium,
                // Előbb a régi halványul el, csak utána jön az új: a két szöveg nem úszik egymásra.
                switchInCurve: const Interval(0.45, 1, curve: Curves.easeOut),
                switchOutCurve: const Interval(0.55, 1, curve: Curves.easeIn),
                // Az új tartalom felülre igazodik, így nem „ugrál” a régi és az új között.
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topLeft,
                  children: [...previous, ?current],
                ),
                child: content,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < count; i++)
                  AnimatedContainer(
                    duration: medium,
                    curve: Motion.curve,
                    width: i == index ? 16 : 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: i == index ? AppColors.primary : AppColors.divider,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                // Az utolsó lépésnél a „Kihagyom” elhalványul (a helye megmarad, hogy ne ugorjon semmi).
                AnimatedOpacity(
                  opacity: last ? 0 : 1,
                  duration: medium,
                  child: IgnorePointer(
                    ignoring: last,
                    child: TextButton(onPressed: onSkip, child: const Text('Kihagyom')),
                  ),
                ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(96, 40)),
                  onPressed: onNext,
                  child: AnimatedSwitcher(
                    duration: medium,
                    child: Text(last ? 'Kezdjük!' : 'Tovább', key: ValueKey(last)),
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

/// Sötét réteg, rajta lekerekített „lyuk” a kiemelt elem fölött.
class _HolePainter extends CustomPainter {
  _HolePainter({required this.hole, required this.color});

  final Rect? hole;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final all = Path()..addRect(Offset.zero & size);
    final h = hole;
    final path = h == null
        ? all
        : Path.combine(PathOperation.difference, all, Path()..addRRect(RRect.fromRectAndRadius(h, const Radius.circular(14))));
    canvas.drawPath(path, Paint()..color = color);
    if (h != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(h, const Radius.circular(14)),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_HolePainter old) => old.hole != hole || old.color != color;
}
