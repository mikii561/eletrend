import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'store.dart';

/// Biztonsági mentés fájlba és visszatöltés. Telefonon a mentés helyét a
/// felhasználó választja, böngészőben letöltésként jelenik meg.
class Backup {
  static Future<void> export(BuildContext context, AppStore store) async {
    final name = 'eletrend-mentes-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json';
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await FilePicker.saveFile(
        fileName: name,
        bytes: utf8.encode(store.exportBackup()),
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
        title: const Text('Visszatöltöd a mentést?'),
        content: const Text('A mentésben lévő adatok a mostaniak helyére kerülnek. '
            'Ha a mostaniakra is szükséged lehet, előbb mentsd el őket.'),
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
      await store.importBackup(utf8.decode(await files.first.readAsBytes()));
      messenger.showSnackBar(SnackBar(
        content: Text('Visszatöltve: ${store.journal.length} naplóbejegyzés, ${store.habits.length} szokás, '
            '${store.events.length} program.'),
      ));
    } on FormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Ezt a fájlt nem tudom beolvasni.')));
    }
  }
}
