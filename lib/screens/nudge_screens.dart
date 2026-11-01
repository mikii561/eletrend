import '../l10n/l10n.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart' hide Text;

import '../l10n/text.dart';

import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../nudges.dart';
import '../voice.dart';
import '../widgets/voice_player.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'invite_screen.dart';

/// Bökés írása egy vagy több barátnak: kész szövegek vagy saját, legfeljebb 120 karakter.
Future<void> showNudgeComposer(
  BuildContext context, {
  required Map<String, String> to,
  String? eventId,
  String? eventTitle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _NudgeComposer(to: to, eventId: eventId, eventTitle: eventTitle),
  );
}

class _NudgeComposer extends StatefulWidget {
  const _NudgeComposer({required this.to, this.eventId, this.eventTitle});

  final Map<String, String> to;
  final String? eventId;
  final String? eventTitle;

  @override
  State<_NudgeComposer> createState() => _NudgeComposerState();
}

class _NudgeComposerState extends State<_NudgeComposer> {
  final _text = TextEditingController();
  String _emoji = nudgeTemplates.first.$1;
  bool _sending = false;
  String? _error;
  String? _image;
  ({String audio, String mime})? _voice;
  VoiceRecorder? _recorder;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder?.cancel();
    _text.dispose();
    super.dispose();
  }

  /// Kép a bökéshez: fotó a kamerával vagy a galériából (kicsinyítve, hogy beférjen).
  Future<void> _pickImage() async {
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
              title: const Text('Kép vagy GIF a galériából'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final picked = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600);
      if (picked == null) return;
      final image = prepareAttachmentImage(await picked.readAsBytes(), name: picked.name);
      if (mounted) {
        setState(() {
          _image = image;
          _error = null;
        });
      }
    } on AttachmentException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = tr('Nem sikerült a képet megnyitni. Engedélyezted az appnak a kamerát vagy a képeket?'),
        );
      }
    }
  }

  /// Hangüzenet: koppintásra indul, újabb koppintásra (vagy 20 mp után) megáll.
  Future<void> _toggleRecording() async {
    if (_recorder != null) return _stopRecording();
    final rec = VoiceRecorder();
    try {
      if (!await rec.start()) {
        setState(() => _error = tr('Nincs engedély a mikrofonhoz. Engedélyezd, és próbáld újra.'));
        return;
      }
    } catch (_) {
      setState(() => _error = tr('A hangfelvétel most nem indítható.'));
      return;
    }
    setState(() {
      _recorder = rec;
      _error = null;
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      if (rec.elapsed >= maxVoiceDuration) {
        _stopRecording();
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _stopRecording() async {
    _ticker?.cancel();
    final rec = _recorder;
    if (rec == null) return;
    setState(() => _recorder = null);
    final voice = await rec.stop();
    await rec.dispose();
    if (mounted) setState(() => _voice = voice);
  }

  Future<void> _send() async {
    final store = StoreScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (_recorder != null) await _stopRecording();
    final text = _text.text.trim();
    if (text.isEmpty && _image == null && _voice == null) {
      if (mounted) setState(() => _error = tr('Válassz egy szöveget, írj sajátot, vagy csatolj képet vagy hangot.'));
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final failed = <String>[];
    for (final e in widget.to.entries) {
      try {
        await Nudges.instance.send(
          e.key,
          fromName: store.myName,
          text: text,
          emoji: _emoji,
          eventId: widget.eventId,
          eventTitle: widget.eventTitle,
          image: _image,
          audio: _voice?.audio,
          audioMime: _voice?.mime,
        );
      } catch (err) {
        failed.add(e.value);
      }
    }
    if (!mounted) return;
    setState(() => _sending = false);
    if (failed.length == widget.to.length) {
      setState(
        () =>
            _error = tr('Nem ment ki. Lehet, hogy ma már elég bökést küldtél, kikapcsolta őket, vagy nincs internet.'),
      );
      return;
    }
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failed.isEmpty ? tr('Elküldve.') : trf('Elküldve, kivéve: {0} (napi keret vagy kikapcsolta).', [failed.join(', ')]),
        ),
      ),
    );
  }

  Widget _attachments(BuildContext context) {
    final recording = _recorder != null;
    final seconds = _recorder?.elapsed.inSeconds ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: recording ? null : _pickImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(_image == null ? tr('Kép') : tr('Másik kép')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: recording ? OutlinedButton.styleFrom(foregroundColor: AppColors.danger) : null,
                onPressed: _toggleRecording,
                icon: Icon(recording ? Icons.stop_circle_outlined : Icons.mic_none),
                label: Text(
                  recording
                      ? trf('Leállítás ({0} mp)', [seconds])
                      : (_voice == null ? tr('Hangüzenet') : tr('Új hangüzenet')),
                ),
              ),
            ),
          ],
        ),
        if (_image != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    base64Decode(_image!),
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(onPressed: () => setState(() => _image = null), child: const Text('Kép törlése')),
              ],
            ),
          ),
        if (_voice != null && !recording)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                VoicePlayer(audio: _voice!.audio, mime: _voice!.mime),
                const SizedBox(width: 8),
                TextButton(onPressed: () => setState(() => _voice = null), child: const Text('Törlés')),
              ],
            ),
          ),
        const SizedBox(height: 4),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(trf('Bökés: {0}', [widget.to.values.join(', ')]), style: Theme.of(context).textTheme.titleLarge),
          if (widget.eventTitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(trf('Program: {0}', [widget.eventTitle]), style: TextStyle(color: AppColors.textMuted)),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (emoji, text) in nudgeTemplates)
                ActionChip(
                  label: Text('$emoji ${tr(text)}'),
                  onPressed: () => setState(() {
                    _emoji = emoji;
                    _text.text = tr(text);
                    _error = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: tr('Vagy írd meg a sajátodat…'), errorText: _error),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 4),
          _attachments(context),
          Text(
            trf('Naponta legfeljebb {0} bökés mehet ugyanannak a barátnak, hogy ne legyen tolakodó.', [
              Nudges.dailyLimit,
            ]),
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: const Icon(Icons.waving_hand_outlined),
            label: Text(_sending ? tr('Küldés…') : tr('Bökés küldése')),
          ),
        ],
      ),
    );
  }
}

/// A kapott bökések listája.
class NudgeInboxScreen extends StatefulWidget {
  const NudgeInboxScreen({super.key});

  @override
  State<NudgeInboxScreen> createState() => _NudgeInboxScreenState();
}

class _NudgeInboxScreenState extends State<NudgeInboxScreen> {
  @override
  void initState() {
    super.initState();
    // A lista megnyitásával mind olvasott (a számláló eltűnik).
    Nudges.instance.markAllSeen().catchError((Object e) => debugPrint('Olvasottnak jelölés később: $e'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bökések')),
      body: !Nudges.instance.ready
          ? const Center(child: LoadingState())
          : StreamBuilder<List<Nudge>>(
              stream: Nudges.instance.watchAll(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Padding(
                    padding: EdgeInsets.all(16),
                    child: ErrorState(text: tr('Nem töltődtek be. Van internet?')),
                  );
                }
                if (!snap.hasData) return const Center(child: LoadingState());
                final list = snap.data!;
                if (list.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [EmptyState(emoji: '👋', text: tr('Még nem bökött meg senki.'))],
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final n in list)
                      Card(
                        child: ListTile(
                          leading: n.image != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    base64Decode(n.image!),
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                  ),
                                )
                              : Text(n.emoji, style: const TextStyle(fontSize: 26)),
                          title: Text(
                            n.text.isNotEmpty
                                ? n.text
                                : (n.image != null ? tr('Képet küldött') : tr('Hangüzenetet küldött')),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            [
                              n.fromName,
                              if (n.at != null) DateFormat(tr('MMM d. HH:mm'), L10n.code).format(n.at!),
                              if (n.eventTitle != null) n.eventTitle!,
                              if (n.audio != null) tr('🎙️ hangüzenet'),
                            ].join(' · '),
                          ),
                          onTap: () => openNudge(context, n),
                          trailing: IconButton(
                            tooltip: tr('Törlés'),
                            icon: const Icon(Icons.close),
                            onPressed: () => Nudges.instance.delete(n.id),
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

/// Egy bökés megnyitása: ha programhoz kötött, a program nyílik meg; különben a lista.
bool _nudgeOpen = false;

/// Közben (amíg egy bökés oldala nyitva van, vagy épp nyílik) a további koppintásokat figyelmen kívül hagyjuk,
/// különben többször nyílna meg ugyanaz az oldal, és mindet külön be kellene zárni.
Future<void> openNudge(BuildContext context, Nudge n) async {
  if (_nudgeOpen) return;
  _nudgeOpen = true;
  try {
    Nudges.instance.markSeen(n.id).catchError((_) {});
    final id = n.eventId;
    // Képes vagy hangos bökésnél először a tartalom jön (a programot onnan lehet megnyitni).
    final Widget page = n.hasMedia
        ? NudgeDetailScreen(nudge: n)
        : (id == null ? const NudgeInboxScreen() : InviteScreen(eventId: id));
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  } finally {
    _nudgeOpen = false;
  }
}

/// Egy kapott bökés képpel vagy hanggal: a kép, a szöveg, a hangüzenet lejátszása és a program.
class NudgeDetailScreen extends StatelessWidget {
  const NudgeDetailScreen({super.key, required this.nudge, this.autoplay = false});

  final Nudge nudge;

  /// Megnyitáskor magától lejátssza a hangot.
  final bool autoplay;

  @override
  Widget build(BuildContext context) {
    final n = nudge;
    final eventId = n.eventId;
    return Scaffold(
      appBar: AppBar(title: Text(n.fromName)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (n.image != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(base64Decode(n.image!), fit: BoxFit.contain, gaplessPlayback: true),
            ),
          if (n.text.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('${n.emoji} ${n.text}', style: Theme.of(context).textTheme.titleLarge),
          ],
          if (n.audio != null) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: VoicePlayer(audio: n.audio!, mime: n.audioMime ?? 'audio/mp4', autoplay: autoplay),
            ),
          ],
          if (n.at != null) ...[
            const SizedBox(height: 12),
            Text(DateFormat(tr('MMM d. HH:mm'), L10n.code).format(n.at!), style: TextStyle(color: AppColors.textMuted)),
          ],
          if (eventId != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => InviteScreen(eventId: eventId))),
              icon: const Icon(Icons.event_outlined),
              label: Text(n.eventTitle == null ? tr('Program megnyitása') : trf('Program: {0}', [n.eventTitle])),
            ),
          ],
        ],
      ),
    );
  }
}
