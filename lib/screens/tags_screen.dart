import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';
import '../photos.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/tag_icon.dart';

/// A hangulatarcok és -címkék kezelése: láthatóság, sorrend, átnevezés, új címke.
class TagsScreen extends StatelessWidget {
  const TagsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final tags = store.moodTags;

    return Scaffold(
      appBar: AppBar(title: const Text('Hangulatok és címkék')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTagEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Új címke', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        buildDefaultDragHandles: false,
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Milyen napod van?'),
            Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Text('Koppints egy arcra, és cseréld le bármilyen emojira vagy saját képre.',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (var m = 1; m <= 5; m++)
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => showMoodEditor(context, m),
                        child: SizedBox(
                          width: 60,
                          child: Column(
                            children: [
                              MoodFace(m, size: 40),
                              const SizedBox(height: 6),
                              Text(store.moodFace(m).name,
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SectionTitle('Címkék'),
            Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Text(
                'Koppints egy címkére az átnevezéshez vagy az ikon cseréjéhez. A kapcsolóval elrejtheted a naplóból, '
            'a ⠿ fogantyúval átrendezheted.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
        itemCount: tags.length,
        onReorderItem: store.moveTag,
        itemBuilder: (context, i) {
          final t = tags[i];
          return Card(
            key: ValueKey(t.id),
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              contentPadding: const EdgeInsets.only(left: 16, right: 4),
              leading: Opacity(opacity: t.visible ? 1 : 0.4, child: TagIcon(t, size: 32)),
              title: Text(
                t.name,
                style: TextStyle(fontWeight: FontWeight.w700, color: t.visible ? null : AppColors.textMuted),
              ),
              subtitle: t.visible ? null : const Text('Rejtve'),
              onTap: () => showTagEditor(context, tag: t),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: t.visible,
                    onChanged: (on) => store.updateTag(t..visible = on),
                  ),
                  ReorderableDragStartListener(
                    index: i,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.drag_indicator, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Címke létrehozása (ha [tag] null) vagy szerkesztése alsó lapon.
Future<void> showTagEditor(BuildContext context, {MoodTag? tag}) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TagEditor(store: StoreScope.of(context), tag: tag),
    );

/// Az 1–5 hangulat arcának és feliratának szerkesztése.
Future<void> showMoodEditor(BuildContext context, int mood) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        final store = StoreScope.of(context);
        return _TagEditor(store: store, tag: store.moodFace(mood), mood: mood);
      },
    );

/// Gyorsan választható emojik; bármilyen más is beírható a billentyűzetről.
const _emojiSuggestions = [
  '😀', '😊', '🥰', '😎', '🤩', '🥳', '😇', '🤗', '😌', '😴', '🤔', '😬',
  '😤', '😭', '😱', '🤯', '🥵', '🥶', '🤢', '😷', '🙃', '😏', '🫠', '🥺',
  '❤️', '💔', '🔥', '⭐', '🌈', '☀️', '🌧️', '⚡', '🍀', '🌸', '🎵', '🎮',
  '📚', '🏃', '🧘', '🍕', '☕', '🍷', '🐶', '🐱', '💼', '💸', '🏠', '✈️',
];

class _TagEditor extends StatefulWidget {
  const _TagEditor({required this.store, this.tag, this.mood});

  final AppStore store;
  final MoodTag? tag;

  /// Ha meg van adva, egy hangulatarcot szerkesztünk, nem címkét.
  final int? mood;

  @override
  State<_TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends State<_TagEditor> {
  late final _name = TextEditingController(text: widget.tag?.name);
  late final _emojiField = TextEditingController();
  late String _emoji = widget.tag?.emoji ?? '😊';
  late String? _image = widget.tag?.image;
  String? _error;
  String? _imageError;

  /// Előnézet a még el nem mentett beállításokkal.
  MoodTag get _preview => MoodTag(id: 'preview', name: _name.text, emoji: _emoji, image: _image);

  void _setEmoji(String e) => setState(() {
        _emoji = e;
        _image = null;
      });

  /// A mezőbe írt szövegből az utolsó karakter (emoji) lesz az ikon.
  void _onEmojiTyped(String value) {
    final chars = value.trim().characters;
    if (chars.isEmpty) return;
    _setEmoji(chars.last);
    _emojiField.clear();
  }

  Future<void> _pickImage() async {
    // Böngészőben is felajánljuk a kamerát: telefonon az nyitja meg a fényképezőt.
    final source = await showModalBottomSheet<ImageSource>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Fotó készítése'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Választás a galériából'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    if (source == null) return;
    try {
      final image = await TagImages.pick(source);
      if (image != null) {
        setState(() {
          _image = image;
          _imageError = null;
        });
      }
    } catch (e) {
      // A lap mögötti képernyőn a SnackBar nem látszana, ezért itt írjuk ki.
      if (mounted) setState(() => _imageError = e is UnsupportedImage ? e.toString() : 'Nem sikerült betölteni a képet. Próbáld újra, vagy válassz másikat.');
    }
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return setState(() => _error = _isMood ? 'Adj neki feliratot' : 'Adj nevet a címkének');
    if (!_isMood && widget.store.tagNameTaken(name, except: widget.tag)) {
      return setState(() => _error = 'Már van ilyen nevű címke');
    }
    final tag = widget.tag;
    if (tag == null) {
      widget.store.addTag(name: name, emoji: _emoji, image: _image);
    } else {
      widget.store.updateTag(tag
        ..name = name
        ..emoji = _emoji
        ..image = _image);
    }
    Navigator.pop(context);
  }

  bool get _isMood => widget.mood != null;

  void _resetMood() {
    widget.store.resetMoodFace(widget.mood!);
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final tag = widget.tag!;
    final used = widget.store.tagUsage(tag);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Törlöd: „${tag.name}”?'),
        content: Text(used == 0
            ? 'Még egyik bejegyzésedben sem szerepel.'
            : '$used bejegyzésedből is eltűnik. Ha csak nem szeretnéd látni, inkább rejtsd el a kapcsolóval.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Mégse')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade400),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Törlés'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    widget.store.removeTag(tag);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _name.dispose();
    _emojiField.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isMood
                  ? 'Hangulat: ${widget.mood}/5'
                  : widget.tag == null
                      ? 'Új címke'
                      : 'Címke szerkesztése',
              style: theme.textTheme.titleLarge,
            ),
            if (_isMood)
              Text('Válassz emojit, vagy tölts fel képet, akár egy szelfit is a mostani arcodról.',
                  style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(20)),
                  child: TagIcon(_preview, size: 52, circle: _isMood),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: _name,
                    autofocus: widget.tag == null,
                    textCapitalization: TextCapitalization.none,
                    decoration: InputDecoration(
                      labelText: _isMood ? 'Felirat' : 'Név',
                      hintText: _isMood ? 'pl. Szuper nap' : 'pl. kalandvágyó',
                      errorText: _error,
                    ),
                    onChanged: (_) => setState(() => _error = null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Ikon', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emojiField,
                    decoration: const InputDecoration(
                      hintText: 'Írj be bármilyen emojit',
                      prefixIcon: Icon(Icons.emoji_emotions_outlined),
                    ),
                    onChanged: _onEmojiTyped,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Saját kép'),
                ),
              ],
            ),
            if (_imageError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_imageError!, style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w600)),
              ),
            if (_image != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _image = null),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Kép eltávolítása (vissza az emojihoz)'),
                ),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 2,
              runSpacing: 2,
              children: [
                for (final e in _emojiSuggestions)
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _setEmoji(e),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: _image == null && _emoji == e ? AppColors.primary.withValues(alpha: 0.18) : null,
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (_isMood) ...[
                  OutlinedButton(onPressed: _resetMood, child: const Text('Alapra')),
                  const SizedBox(width: 10),
                ] else if (widget.tag != null) ...[
                  OutlinedButton(
                    onPressed: _delete,
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade400),
                    child: const Text('Törlés'),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(child: FilledButton(onPressed: _save, child: const Text('Mentés'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
