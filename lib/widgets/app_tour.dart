import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';
import 'memories_demo.dart';

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

  void _next() => _i + 1 >= widget.steps.length ? widget.onDone() : setState(() => _i++);

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
    return LayoutBuilder(
      builder: (context, c) {
        final hole = _targetRect(context);
        final size = Size(c.maxWidth, c.maxHeight);
        // A kártya a kiemelés alá kerül, ha felül van; fölé, ha alul; középre, ha nincs kiemelés.
        final below = hole != null && hole.center.dy < size.height / 2;
        final card = _TourCard(
          step: step,
          index: _i,
          count: widget.steps.length,
          last: last,
          onNext: _next,
          onSkip: widget.onDone,
        );
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _next,
                  child: CustomPaint(painter: _HolePainter(hole: hole, color: Colors.black.withValues(alpha: 0.6))),
                ),
              ),
              if (hole == null)
                Center(child: Padding(padding: const EdgeInsets.all(24), child: card))
              else
                Positioned(
                  left: 16,
                  right: 16,
                  top: below ? min(hole.bottom + 12, size.height - 220) : null,
                  bottom: below ? null : max(12, size.height - hole.top + 12),
                  child: card,
                ),
            ],
          ),
        );
      },
    );
  }
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
          child: Column(
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
              const SizedBox(height: 12),
              Row(
                children: [
                  for (var i = 0; i < count; i++)
                    Container(
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
                  if (!last) TextButton(onPressed: onSkip, child: const Text('Kihagyom')),
                  const Spacer(),
                  const SizedBox(width: 4),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(96, 40)),
                    onPressed: onNext,
                    child: Text(last ? 'Kezdjük!' : 'Tovább'),
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
