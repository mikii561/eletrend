import 'dart:io';

import 'l10n_rewrite.dart' show Lexer;

final _hu = RegExp('[áéíóöőúüűÁÉÍÓÖŐÚÜŰ]');

void main() {
  final out = <String>[];
  for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart') && !f.path.contains('l10n'))) {
    final src = f.readAsStringSync();
    final lx = Lexer(src)..run();
    final toks = lx.toks;
    final lineStarts = <int>[0];
    for (var i = 0; i < src.length; i++) {
      if (src[i] == '\n') lineStarts.add(i + 1);
    }
    for (var k = 0; k < toks.length; k++) {
      final t = toks[k];
      if (t.kind != 's') continue;
      final st = t.str!;
      final plain = st.parts.map((p) => p.isExpr ? '{}' : p.src).join();
      if (_hu.hasMatch(plain)) continue;
      if (!RegExp(r'[A-Za-z]{3,}').hasMatch(plain)) continue;
      final prev = k > 0 ? toks[k - 1] : null;
      final prev2 = k > 1 ? toks[k - 2] : null;
      if (prev != null && (const {'import', 'export', 'part', 'library'}.contains(prev.text))) continue;
      if (prev != null && prev.text == '(' && prev2 != null && const {'debugPrint', 'print', 'Key', 'ValueKey', 'tr', 'trf', 'parse', 'RegExp', 'collection', 'doc', 'getString', 'setString', 'getBool', 'setBool', 'remove', 'containsKey', 'DateFormat', 'asset', 'Image.asset'}.contains(prev2.text)) continue;
      if (prev != null && prev.text == '[' ) continue;
      if (plain.contains('/') || plain.contains('_') || plain.startsWith('http') || plain.contains('package:')) continue;
      if (RegExp(r'^[a-z][A-Za-z0-9]*$').hasMatch(plain)) continue; // azonosító jellegű
      final off = t.start;
      var line = 0;
      while (line + 1 < lineStarts.length && lineStarts[line + 1] <= off) {
        line++;
      }
      final path = f.path.split(Platform.pathSeparator).join('/');
      out.add('$path:${line + 1}: $plain');
    }
  }
  File(Platform.environment['OUT']!).writeAsStringSync(out.join('\n'));
  stdout.writeln(out.length);
}
