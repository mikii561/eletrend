import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../formatting.dart';
import '../memories.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_screen.dart' show showMemoriesExample;
import 'social_widgets.dart';

/// Fotók kiválasztása és feltöltése egy közös programhoz. Előtte megkérdezi, ki láthatja őket,
/// és letölthetik-e mások.
Future<void> uploadMemoryPhotos(BuildContext context, String eventId) async {
  final messenger = ScaffoldMessenger.of(context);
  final name = await ensureMyName(context);
  if (name == null || !context.mounted) return;
  final List<XFile> files;
  try {
    // A telefon/böngésző már itt kicsinyít, hogy a feldolgozás gyors legyen.
    files = await ImagePicker().pickMultiImage(maxWidth: 1600, maxHeight: 1600, imageQuality: 85, limit: 10);
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Nem sikerült megnyitni a képeket: $e')));
    return;
  }
  if (files.isEmpty || !context.mounted) return;
  final options = await showModalBottomSheet<(PhotoAudience, bool)>(
    context: context,
    showDragHandle: true,
    builder: (_) => _UploadOptions(count: files.length),
  );
  if (options == null || !context.mounted) return;

  final progress = ValueNotifier(0);
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      content: ValueListenableBuilder<int>(
        valueListenable: progress,
        builder: (_, done, _) => Row(
          children: [
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(width: 16),
            Expanded(child: Text('Feltöltés: $done / ${files.length}')),
          ],
        ),
      ),
    ),
  );
  var failed = 0;
  for (final f in files) {
    try {
      final prepared = Memories.prepare(await f.readAsBytes());
      await Memories.instance.upload(
        eventId,
        name: name,
        full: prepared.full,
        thumb: prepared.thumb,
        audience: options.$1,
        allowDownload: options.$2,
      );
    } catch (_) {
      failed++;
    }
    progress.value++;
  }
  navigator.pop();
  messenger.showSnackBar(SnackBar(
    content: Text(failed == 0
        ? 'Feltöltve: ${files.length} fotó.'
        : '${files.length - failed} fotó feltöltve, $failed nem sikerült (túl nagy vagy nincs internet).'),
  ));
}

class _UploadOptions extends StatefulWidget {
  const _UploadOptions({required this.count});

  final int count;

  @override
  State<_UploadOptions> createState() => _UploadOptionsState();
}

class _UploadOptionsState extends State<_UploadOptions> {
  PhotoAudience _audience = PhotoAudience.all;
  bool _download = true;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${widget.count} fotó feltöltése', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Ki láthatja?', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
            RadioGroup<PhotoAudience>(
              groupValue: _audience,
              onChanged: (v) => setState(() => _audience = v ?? _audience),
              child: Column(
                children: [for (final a in PhotoAudience.values) RadioListTile(value: a, title: Text(a.label))],
              ),
            ),
            SwitchListTile(
              title: const Text('Mások is letölthetik'),
              subtitle: const Text('Kikapcsolva csak megnézni tudják.'),
              value: _download,
              onChanged: (v) => setState(() => _download = v),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, (_audience, _download)),
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Feltöltés'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kis előnézetek egy sorban (a program oldalán és a Főoldalon).
class MemoryStrip extends StatefulWidget {
  const MemoryStrip({super.key, required this.eventId, required this.going, this.onOpen, this.canUpload = true});

  final String eventId;
  final bool going;
  final VoidCallback? onOpen;
  final bool canUpload;

  @override
  State<MemoryStrip> createState() => _MemoryStripState();
}

class _MemoryStripState extends State<MemoryStrip> {
  late final _photos = Memories.instance.watch(widget.eventId, going: widget.going);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MemoryPhoto>>(
      stream: _photos,
      builder: (context, snap) {
        final photos = snap.data ?? const <MemoryPhoto>[];
        return SizedBox(
          height: 84,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              if (widget.canUpload)
                _Tile(
                  onTap: () => uploadMemoryPhotos(context, widget.eventId),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary),
                      const SizedBox(height: 2),
                      Text('Fotó', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              if (snap.hasError)
                Center(child: Text('  A fotók nem töltődtek be.', style: TextStyle(color: AppColors.textMuted))),
              if (!snap.hasError && photos.isEmpty && snap.hasData)
                Center(child: Text('  Még nincs fotó. Oszd meg az elsőt!', style: TextStyle(color: AppColors.textMuted))),
              for (final p in photos.take(12))
                _Tile(
                  onTap: widget.onOpen,
                  child: Image.memory(p.thumbBytes, fit: BoxFit.cover, gaplessPlayback: true),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Space.radiusSmall),
        child: Container(
          width: 84,
          height: 84,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(Space.radiusSmall),
            border: Border.all(color: AppColors.divider),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Egy közös program emlékei: mi volt, mikor, hol, és a fotók.
class MemoryScreen extends StatefulWidget {
  const MemoryScreen({
    super.key,
    required this.eventId,
    required this.title,
    required this.start,
    this.place = '',
    this.going = false,
    this.ownerUid,
  });

  final String eventId;
  final String title;
  final DateTime start;
  final String place;

  /// Ott voltam-e („Megyek”): akkor a csak résztvevőknek szóló fotókat is látom.
  final bool going;

  /// A szervező (ő bármelyik fotót törölheti).
  final String? ownerUid;

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  late final _photos = Memories.instance.watch(widget.eventId, going: widget.going);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final past = widget.start.isBefore(now);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emlékek'),
        actions: [
          IconButton(tooltip: 'Hogyan működik?', icon: const Icon(Icons.help_outline), onPressed: () => showMemoriesExample(context)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => uploadMemoryPhotos(context, widget.eventId),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Fotók'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: IconTile(Icons.photo_library_outlined, color: AppColors.category(EventCategory.shared)),
              title: Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              subtitle: Text([
                if (past) agoLabel(widget.start, now),
                DateFormat('yyyy. MMMM d., EEEE', 'hu').format(widget.start),
                if (widget.place.isNotEmpty) widget.place,
              ].join(' · ')),
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<MemoryPhoto>>(
            stream: _photos,
            builder: (context, snap) {
              if (snap.hasError) return const ErrorState(text: 'A fotók nem töltődtek be. Van internet?');
              if (!snap.hasData) return const LoadingState();
              final photos = snap.data!;
              if (photos.isEmpty) {
                return const EmptyState(
                  emoji: '📸',
                  text: 'Még nincs fotó erről a programról.\nTölts fel párat, és a résztvevők is láthatják.',
                );
              }
              return GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final p in photos)
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => _PhotoViewer(eventId: widget.eventId, photo: p, ownerUid: widget.ownerUid),
                      )),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(p.thumbBytes, fit: BoxFit.cover, gaplessPlayback: true),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Egy fotó nagyban: ki töltötte fel, letöltés (ha szabad), a sajátnál beállítás és törlés.
class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.eventId, required this.photo, this.ownerUid});

  final String eventId;
  final MemoryPhoto photo;
  final String? ownerUid;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final Future<Uint8List?> _full = Memories.instance.full(widget.eventId, widget.photo);

  Future<void> _download(Uint8List bytes) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await FilePicker.saveFile(
        fileName: 'lifeup-${widget.photo.id}.jpg',
        bytes: bytes,
        mimeType: 'image/jpeg',
        dialogTitle: 'Hova mentsem?',
      );
      if (saved != null) messenger.showSnackBar(const SnackBar(content: Text('Elmentve.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Nem sikerült a mentés.')));
    }
  }

  Future<void> _settings() async {
    final p = widget.photo;
    var audience = p.audience;
    var download = p.allowDownload;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioGroup<PhotoAudience>(
                groupValue: audience,
                onChanged: (v) => setSheet(() => audience = v ?? audience),
                child: Column(children: [for (final a in PhotoAudience.values) RadioListTile(value: a, title: Text(a.label))]),
              ),
              SwitchListTile(title: const Text('Mások is letölthetik'), value: download, onChanged: (v) => setSheet(() => download = v)),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Mentés')),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    try {
      await Memories.instance.update(widget.eventId, p, audience: audience, allowDownload: download);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSocialError(context, e);
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, title: 'Törlöd a fotót?', action: 'Törlés', danger: true)) return;
    try {
      await Memories.instance.delete(widget.eventId, widget.photo.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSocialError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.photo;
    final me = Memories.instance.uid;
    final mine = p.uid == me;
    final canDelete = mine || widget.ownerUid == me;
    final store = StoreScope.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(mine ? (store.myName.isEmpty ? 'Te' : store.myName) : p.name, style: const TextStyle(color: Colors.white, fontSize: 18)),
        actions: [
          if (mine) IconButton(tooltip: 'Ki láthatja?', icon: const Icon(Icons.lock_outline), onPressed: _settings),
          if (canDelete) IconButton(tooltip: 'Törlés', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: FutureBuilder<Uint8List?>(
        future: _full,
        builder: (context, snap) {
          final bytes = snap.data;
          return Column(
            children: [
              Expanded(
                child: Center(
                  child: InteractiveViewer(
                    maxScale: 4,
                    child: bytes != null
                        ? Image.memory(bytes, fit: BoxFit.contain)
                        : Image.memory(p.thumbBytes, fit: BoxFit.contain, gaplessPlayback: true),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          [
                            if (p.at != null) formatDay(p.at!),
                            if (p.audience == PhotoAudience.going) 'csak a résztvevőknek',
                          ].join(' · '),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      if (bytes != null && (mine || p.allowDownload))
                        TextButton.icon(
                          onPressed: () => _download(bytes),
                          icon: const Icon(Icons.download_outlined, color: Colors.white),
                          label: const Text('Letöltés', style: TextStyle(color: Colors.white)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
