import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'models.dart';
import 'store.dart';
import 'theme.dart';

/// Betűkészletek a PDF-hez, magyar ékezetekkel (a Google Fonts-ból töltődnek le). Emojit szándékosan
/// nem használunk: a színes emoji-betűtípus kb. 10 MB, és PDF-ben sem jelenik meg mindenhol jól.
class PdfFonts {
  const PdfFonts({this.base, this.bold});

  final pw.Font? base;
  final pw.Font? bold;

  static Future<PdfFonts> load() async =>
      PdfFonts(base: await PdfGoogleFonts.nunitoRegular(), bold: await PdfGoogleFonts.nunitoBold());
}

PdfColor _pdfColor(int argb) => PdfColor.fromInt(argb);

/// A napló kinyomtatható, szépen tördelt PDF-ben (hónaponként, régebbitől az újabbig).
Future<Uint8List> buildJournalPdf(
  AppStore store,
  List<JournalEntry> entries, {
  required String title,
  PdfFonts fonts = const PdfFonts(),
}) async {
  final sorted = [...entries]..sort((a, b) => a.date.compareTo(b.date));
  final theme = pw.ThemeData.withFont(base: fonts.base, bold: fonts.bold);
  final primary = _pdfColor(AppColors.primary.toARGB32());
  final muted = PdfColor.fromInt(0xFF7A7A8C);
  final doc = pw.Document(title: title, author: store.myName, creator: 'Életrend');

  pw.Widget entryBlock(JournalEntry e) {
    final face = store.moodFace(e.mood);
    final moodColor = _pdfColor(AppColors.moods[e.mood - 1].toARGB32());
    // A nap saját fotója, vagy ha a hangulatarc saját kép, az.
    final image = e.moodImage != null ? base64Decode(e.moodImage!) : face.imageBytes;
    final dayPhoto = !kIsWeb && e.photoPath != null && File(e.photoPath!).existsSync()
        ? File(e.photoPath!).readAsBytesSync()
        : null;
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border(left: pw.BorderSide(color: moodColor, width: 4)),
        color: PdfColor.fromInt(0xFFF7F6FB),
        // Egyoldali (színes) szegély mellé a pdf csomag nem enged lekerekítést.
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(children: [
                  pw.Text(DateFormat('MMMM d., EEEE', 'hu').format(e.date),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                  pw.SizedBox(width: 8),
                  pw.Text(face.name,
                      style: pw.TextStyle(color: moodColor, fontWeight: pw.FontWeight.bold)),
                ]),
                if (e.tags.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 3),
                    child: pw.Text(
                      e.tags.map((t) => store.tagFor(t).name).join('  ·  '),
                      style: pw.TextStyle(color: muted, fontSize: 9),
                    ),
                  ),
                if (e.gratitude.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 6),
                    child: pw.RichText(
                      text: pw.TextSpan(children: [
                        pw.TextSpan(text: 'Hála: ', style: pw.TextStyle(color: muted)),
                        pw.TextSpan(text: e.gratitude, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ]),
                    ),
                  ),
                if (e.answer.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Text(e.question, style: pw.TextStyle(color: primary, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text(e.answer),
                ],
                if (e.note.isNotEmpty)
                  pw.Padding(padding: const pw.EdgeInsets.only(top: 6), child: pw.Text(e.note)),
              ],
            ),
          ),
          if (image != null || dayPhoto != null) pw.SizedBox(width: 10),
          if (image != null)
            pw.ClipOval(child: pw.Image(pw.MemoryImage(image), width: 44, height: 44, fit: pw.BoxFit.cover)),
          if (dayPhoto != null) ...[
            pw.SizedBox(width: 6),
            pw.ClipRRect(
              horizontalRadius: 6,
              verticalRadius: 6,
              child: pw.Image(pw.MemoryImage(dayPhoto), width: 90, height: 90, fit: pw.BoxFit.cover),
            ),
          ],
        ],
      ),
    );
  }

  // Hónaponként csoportosítva, mindegyik elé egy fejléc.
  final widgets = <pw.Widget>[];
  String? currentMonth;
  for (final e in sorted) {
    final month = DateFormat('yyyy. MMMM', 'hu').format(e.date);
    if (month != currentMonth) {
      currentMonth = month;
      widgets.add(pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8, bottom: 10),
        child: pw.Text(month, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: primary)),
      ));
    }
    widgets.add(entryBlock(e));
  }

  doc.addPage(pw.MultiPage(
    theme: theme,
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(36),
    header: (context) => context.pageNumber == 1
        ? pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: primary)),
            if (store.myName.isNotEmpty) pw.Text(store.myName, style: pw.TextStyle(color: muted, fontSize: 12)),
            pw.Text('${sorted.length} bejegyzés', style: pw.TextStyle(color: muted, fontSize: 10)),
            pw.SizedBox(height: 16),
          ])
        : pw.SizedBox(),
    footer: (context) => pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text('Életrend · ${context.pageNumber}/${context.pagesCount}', style: pw.TextStyle(color: muted, fontSize: 9)),
    ),
    build: (_) => sorted.isEmpty ? [pw.Text('Ebben az időszakban nincs bejegyzés.')] : widgets,
  ));
  return doc.save();
}
