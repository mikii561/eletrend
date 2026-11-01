// Egyszeri eszköz: a magyar szövegeket `tr('…')` / `trf('…', [...])` hívásokba csomagolja,
// és kigyűjti a lefordítandó szövegeket. Futtatás: dart run tool/l10n_rewrite.dart <kimeneti-mappa> [--apply]
import 'dart:io';

final _hu = RegExp('[áéíóöőúüűÁÉÍÓÖŐÚÜŰ]');

class Part {
  Part.text(this.src) : isExpr = false, simple = false;
  Part.expr(this.src, {required this.simple}) : isExpr = true;
  final String src;
  final bool isExpr;
  final bool simple; // $ident
}

class Str {
  Str(this.start, this.end, this.quote, this.parts, {required this.raw, required this.triple});
  final int start;
  final int end;
  final String quote;
  final List<Part> parts;
  final bool raw;
  final bool triple;
  bool get interpolated => parts.any((p) => p.isExpr);
  String get plain => parts.map((p) => p.src).join();
}

class Tok {
  Tok(this.kind, this.text, this.start, this.end, [this.str]);
  final String kind; // id, p (punct), s (string), n (number)
  final String text;
  final int start;
  final int end;
  final Str? str;
}

bool _isIdStart(int c) => (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95 || c == 36;
bool _isIdChar(int c) => _isIdStart(c) || (c >= 48 && c <= 57);

class Lexer {
  Lexer(this.s);
  final String s;
  final toks = <Tok>[];
  int i = 0;

  void run() {
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      if (c == 47 && i + 1 < s.length && s.codeUnitAt(i + 1) == 47) {
        while (i < s.length && s[i] != '\n') {
          i++;
        }
        continue;
      }
      if (c == 47 && i + 1 < s.length && s.codeUnitAt(i + 1) == 42) {
        final e = s.indexOf('*/', i + 2);
        i = e < 0 ? s.length : e + 2;
        continue;
      }
      if (c == 39 || c == 34) {
        toks.add(_string(i, raw: false));
        continue;
      }
      if (c == 114 && i + 1 < s.length && (s.codeUnitAt(i + 1) == 39 || s.codeUnitAt(i + 1) == 34) && (i == 0 || !_isIdChar(s.codeUnitAt(i - 1)))) {
        toks.add(_string(i, raw: true));
        continue;
      }
      if (_isIdStart(c)) {
        final st = i;
        while (i < s.length && _isIdChar(s.codeUnitAt(i))) {
          i++;
        }
        toks.add(Tok('id', s.substring(st, i), st, i));
        continue;
      }
      if (c >= 48 && c <= 57) {
        final st = i;
        while (i < s.length && (_isIdChar(s.codeUnitAt(i)) || s[i] == '.')) {
          i++;
        }
        toks.add(Tok('n', s.substring(st, i), st, i));
        continue;
      }
      if (c == 32 || c == 10 || c == 13 || c == 9) {
        i++;
        continue;
      }
      // pontozás
      final two = i + 1 < s.length ? s.substring(i, i + 2) : '';
      if (two == '==' || two == '!=' || two == '=>' || two == '?.' || two == '??') {
        toks.add(Tok('p', two, i, i + 2));
        i += 2;
        continue;
      }
      toks.add(Tok('p', s[i], i, i + 1));
      i++;
    }
  }

  Tok _string(int start, {required bool raw}) {
    var p = start + (raw ? 1 : 0);
    final q = s[p];
    final triple = s.startsWith(q * 3, p);
    p += triple ? 3 : 1;
    final parts = <Part>[];
    var buf = StringBuffer();
    void flush() {
      if (buf.isNotEmpty) parts.add(Part.text(buf.toString()));
      buf = StringBuffer();
    }

    while (p < s.length) {
      final ch = s[p];
      if (!raw && ch == '\\') {
        buf.write(s.substring(p, p + 2));
        p += 2;
        continue;
      }
      if (triple ? s.startsWith(q * 3, p) : ch == q) {
        break;
      }
      if (!raw && ch == r'$') {
        if (p + 1 < s.length && s[p + 1] == '{') {
          flush();
          var depth = 1;
          var j = p + 2;
          while (j < s.length && depth > 0) {
            final cj = s[j];
            if (cj == '{') {
              depth++;
            } else if (cj == '}') {
              depth--;
              if (depth == 0) break;
            } else if (cj == "'" || cj == '"') {
              final sub = Lexer(s)..i = j;
              final t = sub._string(j, raw: false);
              j = t.end;
              continue;
            }
            j++;
          }
          parts.add(Part.expr(s.substring(p + 2, j), simple: false));
          p = j + 1;
          continue;
        } else if (p + 1 < s.length && _isIdStart(s.codeUnitAt(p + 1)) && s[p + 1] != r'$') {
          flush();
          var j = p + 1;
          while (j < s.length && _isIdChar(s.codeUnitAt(j)) && s[j] != r'$') {
            j++;
          }
          parts.add(Part.expr(s.substring(p + 1, j), simple: true));
          p = j;
          continue;
        }
      }
      buf.write(ch);
      p++;
    }
    flush();
    final end = p + (triple ? 3 : 1);
    i = end;
    return Tok('s', s.substring(start, end), start, end, Str(start, end, q, parts, raw: raw, triple: triple));
  }
}

/// Egy rész eredménye.
class Edit {
  Edit(this.start, this.end, this.text);
  final int start;
  final int end;
  final String text;
}

final keys = <String>{};
final skippedKeys = <String>{};
final manual = <String>[];
final accentless = <String>{};

String _keySrc(Str st) {
  // sablon: a kifejezések helyére {i}
  var n = 0;
  final b = StringBuffer();
  for (final p in st.parts) {
    if (p.isExpr) {
      b.write('{${n++}}');
    } else {
      b.write(p.src);
    }
  }
  return b.toString();
}

void main(List<String> args) {
  final out = Directory(args[0])..createSync(recursive: true);
  final apply = args.contains('--apply');
  final files = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart') && !f.path.contains('l10n'));
  var totalWrapped = 0;
  for (final f in files) {
    final src = f.readAsStringSync();
    final lx = Lexer(src)..run();
    final toks = lx.toks;
    final skip = List<bool>.filled(toks.length, false);

    // Tiltott tartományok: const deklarációk, enum konstansok.
    var depth = 0;
    final enumDepths = <int>[]; // melyik mélységben van enum törzs
    final enumConstsDone = <int, bool>{};
    for (var k = 0; k < toks.length; k++) {
      final t = toks[k];
      if (t.kind == 'p' && (t.text == '{')) {
        depth++;
        if (k >= 2 && toks[k - 2].text == 'enum') {
          enumDepths.add(depth);
          enumConstsDone[depth] = false;
        }
        continue;
      }
      if (t.kind == 'p' && t.text == '}') {
        if (enumDepths.isNotEmpty && enumDepths.last == depth) enumDepths.removeLast();
        depth--;
        continue;
      }
      // enum konstansok: a törzs elejétől az első ';'-ig (mélység = enumDepth)
      if (enumDepths.isNotEmpty && depth == enumDepths.last && enumConstsDone[depth] == false) {
        if (t.kind == 'p' && t.text == ';') {
          enumConstsDone[depth] = true;
        } else {
          skip[k] = true;
        }
      }
      // const / final deklaráció
      final prev = k > 0 ? toks[k - 1] : null;
      final startsDecl = prev == null || (prev.kind == 'p' && (prev.text == ';' || prev.text == '}' || prev.text == '{')) || (prev.kind == 'id' && prev.text == 'static') || (prev.kind == 'p' && prev.text == ']');
      final isDeclStart = t.kind == 'id' && (t.text == 'const' || t.text == 'final') && startsDecl;
      if (isDeclStart && (depth == 0 || (depth >= 1 && (prev?.text == 'static')) || (depth == 1 && t.text == 'const'))) {
        // a deklaráció vége: a ';' ugyanazon a zárójelmélységen
        var par = 0;
        var m = k;
        for (; m < toks.length; m++) {
          final tm = toks[m];
          if (tm.kind == 'p') {
            if (tm.text == '(' || tm.text == '[' || tm.text == '{') par++;
            if (tm.text == ')' || tm.text == ']' || tm.text == '}') par--;
            if (tm.text == ';' && par == 0) break;
            if (par < 0) break;
          }
        }
        // csak ha nem konstruktor/függvény törzs: ha '=' van a deklarációban
        var hasEq = false;
        for (var q = k; q < m && q < toks.length; q++) {
          if (toks[q].text == '=' && toks[q].kind == 'p') {
            hasEq = true;
            break;
          }
          if (toks[q].text == '{' || toks[q].text == '=>') break;
        }
        if (hasEq) {
          for (var q = k; q < m && q < toks.length; q++) {
            skip[q] = true;
          }
        }
      }
    }

    final edits = <Edit>[];
    for (var k = 0; k < toks.length; k++) {
      final t = toks[k];
      if (t.kind != 's') continue;
      // szomszédos literálok összevonása (ugyanaz az idézőjel): az első kezeli
      final st = t.str!;
      if (st.triple) {
        if (_hu.hasMatch(st.plain)) manual.add('${f.path}: többsoros szöveg @${t.start}');
        continue;
      }
      var lastIdx = k;
      final merged = <Str>[st];
      while (lastIdx + 1 < toks.length && toks[lastIdx + 1].kind == 's' && toks[lastIdx + 1].str!.quote == st.quote && !toks[lastIdx + 1].str!.triple) {
        merged.add(toks[lastIdx + 1].str!);
        lastIdx++;
      }
      final allParts = [for (final m in merged) ...m.parts];
      final big = Str(st.start, merged.last.end, st.quote, allParts, raw: st.raw, triple: false);
      final prev = k > 0 ? toks[k - 1] : null;
      final prev2 = k > 1 ? toks[k - 2] : null;
      final next = lastIdx + 1 < toks.length ? toks[lastIdx + 1] : null;
      final hasHu = _hu.hasMatch(big.plain);
      final isSkipCtx = skip[k] ||
          (prev != null && prev.kind == 'id' && const {'import', 'export', 'part', 'library', 'case'}.contains(prev.text)) ||
          (prev != null && prev.kind == 'p' && (prev.text == '==' || prev.text == '!=')) ||
          (prev != null && prev.text == '(' && prev2 != null && const {'debugPrint', 'print', 'Key', 'ValueKey', 'Uri.parse', 'parse', 'RegExp', 'hasMatch'}.contains(prev2.text)) ||
          (prev != null && prev.text == '[' && next != null && next.text == ']') ||
          (next != null && next.text == '==') ||
          (prev != null && prev.text == '@') ||
          (prev != null && prev.kind == 'p' && prev.text == '.' );
      final inText = prev != null && prev.text == '(' && prev2 != null && prev2.text == 'Text' && next != null && (next.text == ')' || next.text == ',');
      final key = _keySrc(big);
      if (!hasHu) {
        if (!isSkipCtx && inText && RegExp(r'[A-Za-zÀ-ž]{2,}').hasMatch(big.plain) && !big.interpolated) accentless.add(key);
        // accentless interpolált vagy más: nem foglalkozunk velük itt
        k = lastIdx;
        continue;
      }
      if (isSkipCtx) {
        if (!(prev != null && prev.text == '(' && prev2 != null && const {'debugPrint', 'print'}.contains(prev2.text))) skippedKeys.add(key);
        k = lastIdx;
        continue;
      }
      keys.add(key);
      if (big.raw) {
        manual.add('${f.path}: raw szöveg @${t.start}');
        k = lastIdx;
        continue;
      }
      if (!big.interpolated) {
        if (inText) {
          k = lastIdx;
          continue; // a Text fordít
        }
        edits.add(Edit(big.start, big.end, 'tr(${st.quote}${big.plain}${st.quote})'));
      } else {
        // sablon + argumentumok
        final tplB = StringBuffer();
        final argList = <String>[];
        var ok = true;
        for (final p in allParts) {
          if (p.isExpr) {
            tplB.write('{${argList.length}}');
            argList.add(p.src);
            if (p.src.contains("'") || p.src.contains('"')) ok = false;
          } else {
            if (RegExp(r'\{\d').hasMatch(p.src)) ok = false;
            tplB.write(p.src);
          }
        }
        if (!ok) {
          manual.add('${f.path}: összetett sablon @${t.start}: ${big.plain}');
          keys.remove(key);
          k = lastIdx;
          continue;
        }
        edits.add(Edit(big.start, big.end, 'trf(${st.quote}${tplB.toString()}${st.quote}, [${argList.join(', ')}])'));
      }
      k = lastIdx;
    }
    if (edits.isEmpty) continue;
    var res = src;
    for (final e in edits.reversed) {
      res = res.replaceRange(e.start, e.end, e.text);
    }
    totalWrapped += edits.length;
    if (apply) f.writeAsStringSync(res);
  }
  File('${out.path}/keys.txt').writeAsStringSync(([...keys]..sort()).join('\n'));
  File('${out.path}/skipped_keys.txt').writeAsStringSync(([...skippedKeys]..sort()).join('\n'));
  File('${out.path}/manual.txt').writeAsStringSync(manual.join('\n'));
  File('${out.path}/accentless.txt').writeAsStringSync(([...accentless]..sort()).join('\n'));
  stdout.writeln('átírva: $totalWrapped, kulcs: ${keys.length}, kihagyott: ${skippedKeys.length}, kézi: ${manual.length}, ékezet nélküli: ${accentless.length}');
}
