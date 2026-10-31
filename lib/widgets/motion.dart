import 'package:flutter/material.dart';

/// Az app mozgásai egy helyen: rövidek és lágyak, hogy segítsenek követni, mi hová került,
/// de ne vonják el a figyelmet. Ha a rendszerben ki vannak kapcsolva az animációk, nincs mozgás.
class Motion {
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 420);

  /// Kilépő/belépő mozgások görbéje (gyors indulás, puha megállás).
  static const curve = Curves.easeOutCubic;

  /// Helyváltoztatás (pl. a bemutató kiemelése egyik elemről a másikra).
  static const emphasized = Curves.easeInOutCubicEmphasized;

  /// Kérte-e a felhasználó a mozgások csökkentését.
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// A [d] időtartam, vagy nulla, ha a mozgás ki van kapcsolva.
  static Duration of(BuildContext context, Duration d) => reduced(context) ? Duration.zero : d;
}

/// Egyszeri, finom beúszás megjelenéskor: áttetszőből teljesbe, közben pár képpontot emelkedik.
/// A [delay] a lépcsőzéshez (több egymás alatti elemnél).
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.delay = Duration.zero, this.offset = 12});

  final Widget child;
  final Duration delay;

  /// Ennyi képponttal lejjebbről indul.
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: Motion.medium);
  late final _t = CurvedAnimation(parent: _c, curve: Motion.curve);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context)) {
      _c.value = 1;
    } else if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(offset: Offset(0, widget.offset * (1 - _t.value)), child: child),
      ),
    );
  }
}

