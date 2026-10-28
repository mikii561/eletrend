import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// A bumphoz választható effektek.
enum BumpEffect {
  none('Nincs', '🚫'),
  confetti('Konfetti', '🎊'),
  fireworks('Tűzijáték', '🎆'),
  hearts('Szívek', '💖'),
  emojiRain('Emojieső', '🌧️');

  const BumpEffect(this.label, this.emoji);

  final String label;
  final String emoji;
}

/// Mit mutassunk egy bumpnál: effekt, kép/GIF vagy nagy emoji, és egy rövid felirat.
class EffectShow {
  const EffectShow({this.effect = BumpEffect.none, this.image, this.sticker, this.caption, this.rainEmoji});

  final BumpEffect effect;

  /// Kép vagy (animált) GIF bájtjai: felugrik, billeg, majd leesik és elhalványul.
  final Uint8List? image;

  /// Nagy emoji „matrica” ugyanígy.
  final String? sticker;

  /// Pl. „Gabi bumpolt: Ne felejtsd a pizzát!”
  final String? caption;

  /// Az emojieső emojija (alapból a matrica vagy 🎉).
  final String? rainEmoji;
}

/// Effekt lejátszása az app fölött (nem akadályozza a használatot), ~3,5 mp után eltűnik.
void playEffect(BuildContext context, EffectShow show) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay != null) playEffectOn(overlay, show);
}

/// Ugyanez egy már elkért [OverlayState]-re (aszinkron lépések után, amikor a context már nem használható).
void playEffectOn(OverlayState overlay, EffectShow show) {
  if (!overlay.mounted) return;
  late OverlayEntry entry;
  entry = OverlayEntry(
    // Material nélkül a szövegek (emojik) sárga aláhúzással jelennének meg.
    builder: (_) => IgnorePointer(
      child: Material(
        type: MaterialType.transparency,
        child: _EffectLayer(show: show, onDone: () => entry.remove()),
      ),
    ),
  );
  overlay.insert(entry);
}

class _EffectLayer extends StatefulWidget {
  const _EffectLayer({required this.show, required this.onDone});

  final EffectShow show;
  final VoidCallback onDone;

  @override
  State<_EffectLayer> createState() => _EffectLayerState();
}

class _EffectLayerState extends State<_EffectLayer> with SingleTickerProviderStateMixin {
  static const duration = Duration(milliseconds: 3600);
  late final _c = AnimationController(vsync: this, duration: duration)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    })
    ..forward();
  final _seed = Random().nextInt(1 << 30);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final show = widget.show;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (show.effect != BumpEffect.none)
              CustomPaint(
                painter: _ParticlePainter(
                  effect: show.effect,
                  t: t,
                  seed: _seed,
                  emoji: show.rainEmoji ?? show.sticker ?? '🎉',
                ),
              ),
            if (show.image != null || show.sticker != null) _popAndFall(t, show),
            if (show.caption != null) _caption(t, show.caption!),
          ],
        );
      },
    );
  }

  /// Felugrik (0–0,4 mp), billeg, majd 2,3 mp-től leesik forogva és elhalványul.
  Widget _popAndFall(double t, EffectShow show) {
    final ms = t * duration.inMilliseconds;
    final pop = Curves.elasticOut.transform((ms / 600).clamp(0.0, 1.0));
    final fall = ((ms - 2300) / 1100).clamp(0.0, 1.0);
    final wobble = sin(ms / 140) * 0.06 * (1 - fall);
    final size = MediaQuery.sizeOf(context);
    return Positioned.fill(
      child: Center(
        child: Opacity(
          opacity: (1 - fall).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, Curves.easeIn.transform(fall) * size.height * 0.7),
            child: Transform.rotate(
              angle: wobble + fall * 0.9,
              child: Transform.scale(
                scale: pop,
                child: show.image != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.memory(
                          show.image!,
                          width: min(size.width * 0.6, 280),
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => const Text('🖼️', style: TextStyle(fontSize: 120)),
                        ),
                      )
                    : Text(show.sticker!, style: const TextStyle(fontSize: 140)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _caption(double t, String text) {
    final opacity = t < 0.08 ? t / 0.08 : (t > 0.85 ? (1 - t) / 0.15 : 1.0);
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 24,
      left: 24,
      right: 24,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Center(
          child: Material(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ),
    );
  }
}

/// A részecske-effektek rajzolása. A [seed] alapján minden részecske útja előre meghatározott,
/// így az idő ([t], 0–1) egyértelműen megadja a képet.
class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.effect, required this.t, required this.seed, required this.emoji});

  final BumpEffect effect;
  final double t;
  final int seed;
  final String emoji;

  static const _colors = [
    Color(0xFFFF5A5F), Color(0xFFFFB400), Color(0xFF00A699), Color(0xFF5B5BD6),
    Color(0xFFFF8A65), Color(0xFF81C784), Color(0xFFBA68C8), Color(0xFF4FC3F7),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final r = Random(seed);
    switch (effect) {
      case BumpEffect.none:
        return;
      case BumpEffect.confetti:
        _confetti(canvas, size, r);
      case BumpEffect.fireworks:
        _fireworks(canvas, size, r);
      case BumpEffect.hearts:
        _floating(canvas, size, r, ['❤️', '💖', '💕', '💘'], rising: true, count: 28);
      case BumpEffect.emojiRain:
        _floating(canvas, size, r, [emoji], rising: false, count: 36);
    }
  }

  void _confetti(Canvas canvas, Size size, Random r) {
    final paint = Paint();
    final fade = t > 0.8 ? (1 - t) / 0.2 : 1.0;
    for (var i = 0; i < 140; i++) {
      final x0 = r.nextDouble() * size.width;
      final speed = 0.6 + r.nextDouble() * 0.8;
      final delay = r.nextDouble() * 0.25;
      final sway = r.nextDouble() * 40 + 10;
      final spin = r.nextDouble() * 12 - 6;
      final w = 6 + r.nextDouble() * 6;
      final color = _colors[r.nextInt(_colors.length)];
      final p = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (p <= 0) continue;
      final y = -20 + p * speed * (size.height + 40);
      final x = x0 + sin(p * 10 + i) * sway;
      paint.color = color.withValues(alpha: fade.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p * spin * pi);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: w, height: w * 0.45), paint);
      canvas.restore();
    }
  }

  void _fireworks(Canvas canvas, Size size, Random r) {
    final paint = Paint();
    const sparks = 48;
    for (var b = 0; b < 6; b++) {
      final start = b * 0.12 + r.nextDouble() * 0.05;
      final center = Offset(size.width * (0.12 + r.nextDouble() * 0.76), size.height * (0.12 + r.nextDouble() * 0.42));
      final color = _colors[r.nextInt(_colors.length)];
      final reach = 70 + r.nextDouble() * 70;
      final p = ((t - start) / 0.5).clamp(0.0, 1.0);
      for (var i = 0; i < sparks; i++) {
        // Minden szikrának saját iránya és sebessége, így nem szabályos gyűrű, hanem „robbanás”.
        final angle = r.nextDouble() * 2 * pi;
        final speed = 0.45 + r.nextDouble() * 0.55;
        if (p <= 0 || p >= 1) continue;
        final dist = Curves.easeOut.transform(p) * reach * speed;
        final dir = Offset(cos(angle), sin(angle));
        final gravity = Offset(0, p * p * 55);
        final pos = center + dir * dist + gravity;
        final tail = center + dir * (dist * 0.75) + gravity * 0.8;
        final alpha = (1 - p).clamp(0.0, 1.0);
        paint
          ..color = (i % 7 == 0 ? Colors.white : color).withValues(alpha: alpha)
          ..strokeWidth = 2.2 * (1 - p) + 0.6
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(tail, pos, paint);
        canvas.drawCircle(pos, 2.4 * (1 - p) + 0.8, paint);
      }
    }
  }

  void _floating(Canvas canvas, Size size, Random r, List<String> emojis, {required bool rising, required int count}) {
    for (var i = 0; i < count; i++) {
      final x = r.nextDouble() * size.width;
      final delay = r.nextDouble() * 0.4;
      final speed = 0.7 + r.nextDouble() * 0.6;
      final fontSize = 22 + r.nextDouble() * 22;
      final e = emojis[r.nextInt(emojis.length)];
      final p = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (p <= 0) continue;
      final travel = p * speed * (size.height + 80);
      final y = rising ? size.height + 40 - travel : -40 + travel;
      final painter = TextPainter(
        text: TextSpan(text: e, style: TextStyle(fontSize: fontSize)),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(x + sin(p * 8 + i) * 18, y);
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t;
}
