import 'package:flutter/material.dart' as m;
import 'package:flutter/widgets.dart';

import 'l10n.dart';

/// A Flutter `Text` helyett: az eredeti (magyar) szöveget a mostani nyelvre fordítja kirajzoláskor.
/// A fájlokban `import 'package:flutter/material.dart' hide Text;` mellett ezt kell importálni.
/// Mivel a fordítás a kirajzolásnál történik, a nyelvváltás után a `const Text('…')` is újraépül
/// (lásd `LifeupApp`), és a konstansokban, felsorolásokban lévő magyar szövegek is lefordulnak.
class Text extends StatelessWidget {
  const Text(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  @override
  Widget build(BuildContext context) => m.Text(
    tr(data),
    style: style,
    strutStyle: strutStyle,
    textAlign: textAlign,
    textDirection: textDirection,
    locale: locale,
    softWrap: softWrap,
    overflow: overflow,
    textScaler: textScaler,
    maxLines: maxLines,
    semanticsLabel: semanticsLabel == null ? null : tr(semanticsLabel!),
    textWidthBasis: textWidthBasis,
    textHeightBehavior: textHeightBehavior,
    selectionColor: selectionColor,
  );
}
