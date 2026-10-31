import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'store.dart';

/// Adataid exportálása fájlba (olvasható JSON) és visszatöltése. Telefonon a mentés helyét a
/// felhasználó választja, böngészőben letöltésként jelenik meg.
class Backup {
  static Future<void> export(BuildContext context, AppStore store) async {
    final name = 'lifeup-adataim-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json';
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await FilePicker.saveFile(
        fileName: name,
        bytes: utf8.encode(store.exportData()),
        mimeType: 'application/json',
        dialogTitle: 'Hova mentsem?',
      );
      if (saved == null) return;
      messenger.showSnackBar(SnackBar(content: Text('Elmentve: $name')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Nem sikerült a mentés. Próbáld újra.')));
    }
  }

  static Future<void> restore(BuildContext context, AppStore store) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Visszatöltöd az exportot?'),
        content: const Text(
          'A fájlban lévő adatok a mostaniak helyére kerülnek. '
          'Ha a mostaniakra is szükséged lehet, előbb exportáld őket.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Mégse')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Fájl kiválasztása')),
        ],
      ),
    );
    if (ok != true) return;
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (files.isEmpty) return;
    try {
      store.importData(utf8.decode(await files.first.readAsBytes()));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Visszatöltve: ${store.events.length} bejegyzés, ${store.tasks.length} feladat, '
            '${store.habits.length} cél.',
          ),
        ),
      );
    } on FormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Ezt a fájlt nem tudom beolvasni.')));
    }
  }
}
