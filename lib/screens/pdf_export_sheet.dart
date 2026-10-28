import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../journal_pdf.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';

/// Napló exportálása PDF-be: melyik időszak, aztán megosztás / mentés / nyomtatás.
Future<void> showPdfExportSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _PdfExportSheet(),
    );

class _PdfExportSheet extends StatefulWidget {
  const _PdfExportSheet();

  @override
  State<_PdfExportSheet> createState() => _PdfExportSheetState();
}

class _PdfExportSheetState extends State<_PdfExportSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _export(String title, String file, bool Function(JournalEntry) include) async {
    final store = StoreScope.of(context);
    final entries = store.journal.where(include).toList();
    if (entries.isEmpty) return setState(() => _error = 'Ebben az időszakban nincs bejegyzésed.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await buildJournalPdf(store, entries, title: title, fonts: await PdfFonts.load());
      await Printing.sharePdf(bytes: bytes, filename: file);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = 'Nem sikerült elkészíteni. Van internet? (A betűtípusok letöltéséhez kell.) $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final lastMonth = DateTime(now.year, now.month - 1);
    String name(DateTime m) => DateFormat('yyyy. MMMM', 'hu').format(m);
    bool inMonth(JournalEntry e, DateTime m) => e.date.year == m.year && e.date.month == m.month;
    String fileMonth(DateTime m) => DateFormat('yyyy-MM').format(m);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Napló PDF-ben', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Elmentheted, elküldheted vagy kinyomtathatod. A fotók is benne lesznek.',
                style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 12),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Column(children: [CircularProgressIndicator(), SizedBox(height: 12), Text('Készül a PDF…')]),
              )
            else ...[
              ListTile(
                leading: Icon(Icons.calendar_today_outlined, color: AppColors.primary),
                title: Text('Ez a hónap (${name(thisMonth)})'),
                onTap: () => _export('Napló – ${name(thisMonth)}', 'eletrend-naplo-${fileMonth(thisMonth)}.pdf',
                    (e) => inMonth(e, thisMonth)),
              ),
              ListTile(
                leading: Icon(Icons.history, color: AppColors.primary),
                title: Text('Előző hónap (${name(lastMonth)})'),
                onTap: () => _export('Napló – ${name(lastMonth)}', 'eletrend-naplo-${fileMonth(lastMonth)}.pdf',
                    (e) => inMonth(e, lastMonth)),
              ),
              ListTile(
                leading: Icon(Icons.menu_book_outlined, color: AppColors.primary),
                title: const Text('A teljes napló'),
                onTap: () => _export('Napló', 'eletrend-naplo.pdf', (_) => true),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }
}
