import 'dart:io';

import 'package:eletrend/journal_pdf.dart';
import 'package:eletrend/models.dart';
import 'package:eletrend/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('hu'));

  test('napló PDF: elkészül, hónaponként, képekkel', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    store.setMyName('Gabi');
    store.saveEntry(JournalEntry(id: '1', date: DateTime(2026, 9, 30), mood: 2, note: 'Fárasztó nap.'));
    store.saveEntry(JournalEntry(
      id: '2',
      date: DateTime(2026, 10, 28),
      mood: 5,
      gratitude: 'Hálás vagyok a napsütésért',
      question: 'Mi volt ma a legviccesebb?',
      answer: 'Bence elesett a jégen',
      tags: ['nyugodt', 'hálás'],
    ));

    // Ha a gépen van Arial (Windows), azzal az ékezetek is látszanak; a mintát meg is nézhetjük.
    final arial = File('C:/Windows/Fonts/arial.ttf');
    final arialBold = File('C:/Windows/Fonts/arialbd.ttf');
    final fonts = arial.existsSync()
        ? PdfFonts(
            base: pw.Font.ttf(arial.readAsBytesSync().buffer.asByteData()),
            bold: pw.Font.ttf(arialBold.readAsBytesSync().buffer.asByteData()),
          )
        : const PdfFonts();
    final bytes = await buildJournalPdf(store, store.journal, title: 'Napló', fonts: fonts);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    final out = Platform.environment['ELETREND_PDF_SAMPLE'];
    if (out != null) File(out).writeAsBytesSync(bytes);
  });
}
