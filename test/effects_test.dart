import 'dart:io';
import 'dart:ui' as ui;

import 'package:eletrend/widgets/effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final effect in [BumpEffect.confetti, BumpEffect.fireworks]) {
    testWidgets('effekt lejátszódik és eltűnik: ${effect.name}', (tester) async {
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => playEffect(context, EffectShow(effect: effect, caption: 'Gabi bumpolt!')),
                  child: const Text('Bump'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Bump'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.text('Gabi bumpolt!'), findsOneWidget);

      // Minta kép a szemrevételezéshez, ha kérik.
      final out = Platform.environment['ELETREND_EFFECT_SAMPLE'];
      if (out != null) {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await tester.runAsync(() => boundary.toImage());
        final png = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
        File('$out-${effect.name}.png').writeAsBytesSync(png!.buffer.asUint8List());
      }

      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Gabi bumpolt!'), findsNothing); // magától eltűnt
    });
  }
  testWidgets('az effekt emojijai, feliratai nem kapnak sárga aláhúzást', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => playEffect(
                context,
                const EffectShow(effect: BumpEffect.emojiRain, rainEmoji: '👋', sticker: '👋', caption: 'Márta bumpolt!'),
              ),
              child: const Text('Bump'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Bump'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final texts = find.descendant(of: find.byType(IgnorePointer), matching: find.byType(RichText));
    expect(texts, findsWidgets);
    for (final e in texts.evaluate()) {
      final style = DefaultTextStyle.of(e).style;
      expect(style.decoration, isNot(TextDecoration.underline), reason: 'Material nélküli szöveg az effektben');
    }
    await tester.pump(const Duration(seconds: 5));
  });
}
