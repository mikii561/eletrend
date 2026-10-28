import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../bumps.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/effects.dart';
import 'events_screen.dart';
import 'invite_screen.dart';

const bumpStickers = ['👋', '🍕', '🎉', '⏰', '💪', '😘', '🙏', '🔥', '🥳', '👀', '☕', '🍻'];

/// Effekt lejátszása, ha a felhasználó nem kapcsolta ki az animációkat.
void playBumpEffect(BuildContext context, Bump bump) {
  if (!StoreScope.of(context).effectsOn) return;
  playEffect(context, bump.show);
}

/// Egy bump megnyitása: ha programhoz kötött, a program jön, és rajta ugrik fel a kép/effekt;
/// különben a bump saját képernyője.
Future<void> openBump(BuildContext context, Bump bump) async {
  final store = StoreScope.of(context);
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final overlay = Overlay.of(context, rootOverlay: true);
  if (bump.id.isNotEmpty && !bump.seen) unawaited(Bumps.instance.markSeen(bump.id).catchError((_) {}));
  final mine = bump.eventId == null ? null : store.events.where((e) => e.shareId == bump.eventId).firstOrNull;
  final Widget page = mine != null
      ? EventDetail(event: mine)
      : bump.eventId != null
          ? InviteScreen(eventId: bump.eventId!)
          : BumpDetailScreen(bump: bump);
  unawaited(navigator.push(MaterialPageRoute(builder: (_) => page)));
  // Az új képernyő felépülése után ugrik fel.
  await Future<void>.delayed(const Duration(milliseconds: 450));
  if (!navigator.mounted) return;
  if (store.effectsOn) playEffectOn(overlay, bump.show);
  if (bump.audio != null && page is! BumpDetailScreen) {
    messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 8),
      content: Text('🎙️ ${bump.fromName} hangüzenetet is küldött'),
      action: SnackBarAction(
        label: 'Meghallgatom',
        onPressed: () => navigator.push(MaterialPageRoute(builder: (_) => BumpDetailScreen(bump: bump, autoplay: true))),
      ),
    ));
  }
}

/// Hangüzenet lejátszása (böngészőben data: címről, telefonon a memóriából).
class VoicePlayer extends StatefulWidget {
  const VoicePlayer({super.key, required this.audio, required this.mime, this.autoplay = false});

  final String audio;
  final String mime;
  final bool autoplay;

  @override
  State<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<VoicePlayer> {
  final _player = AudioPlayer();
  bool _playing = false;
  late final StreamSubscription<void> _done = _player.onPlayerComplete.listen((_) {
    if (mounted) setState(() => _playing = false);
  });

  @override
  void initState() {
    super.initState();
    _done; // feliratkozás
    if (widget.autoplay) WidgetsBinding.instance.addPostFrameCallback((_) => _toggle());
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.stop();
      setState(() => _playing = false);
      return;
    }
    setState(() => _playing = true);
    try {
      final source = kIsWeb
          ? UrlSource('data:${widget.mime};base64,${widget.audio}')
          : BytesSource(base64Decode(widget.audio), mimeType: widget.mime);
      await _player.play(source);
    } catch (e) {
      if (!mounted) return;
      setState(() => _playing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nem sikerült lejátszani: $e')));
    }
  }

  @override
  void dispose() {
    _done.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FilledButton.tonalIcon(
        onPressed: _toggle,
        icon: Icon(_playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
        label: Text(_playing ? 'Leállítás' : 'Hangüzenet lejátszása'),
      );
}

/// Egy kapott bump részletesen: kép/matrica, szöveg, hang, effekt újra, a program.
class BumpDetailScreen extends StatelessWidget {
  const BumpDetailScreen({super.key, required this.bump, this.autoplay = false});

  final Bump bump;
  final bool autoplay;

  @override
  Widget build(BuildContext context) {
    final b = bump;
    return Scaffold(
      appBar: AppBar(title: Text('${b.fromName} bumpolt')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (b.image != null)
            ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.memory(b.imageBytes!, fit: BoxFit.contain, gaplessPlayback: true))
          else
            Text(b.sticker ?? '👋', textAlign: TextAlign.center, style: const TextStyle(fontSize: 110)),
          const SizedBox(height: 16),
          if (b.text.isNotEmpty) Text(b.text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          if (b.at != null)
            Text(DateFormat('MMM d., HH:mm', 'hu').format(b.at!), textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 16),
          if (b.audio != null) VoicePlayer(audio: b.audio!, mime: b.audioMime ?? 'audio/mp4', autoplay: autoplay),
          if (b.effect != BumpEffect.none)
            TextButton.icon(
              onPressed: () => playEffect(context, b.show),
              icon: Text(b.effect.emoji),
              label: const Text('Effekt újra'),
            ),
          if (b.eventId != null)
            OutlinedButton.icon(
              onPressed: () => openBump(context, Bump(eventId: b.eventId, fromName: b.fromName, effect: BumpEffect.none, seen: true)),
              icon: const Icon(Icons.event),
              label: Text('A program: ${b.eventTitle ?? ''}'),
            ),
        ],
      ),
    );
  }
}

/// A kapott bumpok listája (visszajátszható).
class BumpsInboxScreen extends StatefulWidget {
  const BumpsInboxScreen({super.key});

  @override
  State<BumpsInboxScreen> createState() => _BumpsInboxScreenState();
}

class _BumpsInboxScreenState extends State<BumpsInboxScreen> {
  late final Stream<List<Bump>>? _all = Bumps.instance.ready ? Bumps.instance.watchAll() : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kapott bumpok')),
      body: _all == null
          ? const Padding(padding: EdgeInsets.all(16), child: EmptyState(emoji: '📡', text: 'Ehhez internet kell.'))
          : StreamBuilder<List<Bump>>(
              stream: _all,
              builder: (context, snap) {
                final list = snap.data;
                if (list == null) return const Center(child: CircularProgressIndicator());
                if (list.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: EmptyState(emoji: '👋', text: 'Még senki nem bumpolt.\nBumpolj meg te valakit!'),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final b in list)
                      Card(
                        child: ListTile(
                          leading: Text(b.sticker ?? (b.image != null ? '🖼️' : '👋'), style: const TextStyle(fontSize: 28)),
                          title: Text(b.headline, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: b.seen ? FontWeight.w500 : FontWeight.w800)),
                          subtitle: Text([
                            if (b.at != null) DateFormat('MMM d., HH:mm', 'hu').format(b.at!),
                            if (b.audio != null) '🎙️ hang',
                            if (b.eventTitle != null) '📅 ${b.eventTitle}',
                          ].join(' · ')),
                          trailing: IconButton(
                            tooltip: 'Törlés',
                            icon: Icon(Icons.delete_outline, color: AppColors.textMuted),
                            onPressed: () => Bumps.instance.delete(b.id),
                          ),
                          onTap: () => openBump(context, b),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

/// Bump írása egy vagy több barátnak, opcionálisan egy programhoz kötve.
Future<void> showBumpComposer(BuildContext context, {required Map<String, String> to, Event? event}) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BumpComposer(to: to, event: event),
    );

class _BumpComposer extends StatefulWidget {
  const _BumpComposer({required this.to, this.event});

  final Map<String, String> to;
  final Event? event;

  @override
  State<_BumpComposer> createState() => _BumpComposerState();
}

class _BumpComposerState extends State<_BumpComposer> {
  final _text = TextEditingController();
  String? _sticker = bumpStickers.first;
  String? _image;
  BumpEffect _effect = BumpEffect.confetti;
  ({String audio, String mime})? _voice;
  VoiceRecorder? _recorder;
  Timer? _ticker;
  bool _busy = false;
  String? _error;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    try {
      final image = Bumps.prepareImage(await picked.readAsBytes(), name: picked.name);
      setState(() {
        _image = image;
        _error = null;
      });
    } on BumpException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _toggleRecording() async {
    if (_recorder != null) return _stopRecording();
    final rec = VoiceRecorder();
    if (!await rec.start()) {
      setState(() => _error = 'Nincs engedély a mikrofonhoz. Engedélyezd, és próbáld újra.');
      return;
    }
    setState(() {
      _recorder = rec;
      _error = null;
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      if (rec.elapsed >= Bumps.maxVoice) {
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
    setState(() {
      _busy = true;
      _error = null;
    });
    final bump = Bump(
      fromUid: '',
      fromName: store.myName,
      text: _text.text.trim(),
      effect: _effect,
      sticker: _sticker,
      image: _image,
      audio: _voice?.audio,
      audioMime: _voice?.mime,
      eventId: widget.event?.shareId,
      eventTitle: widget.event?.title,
    );
    final failed = <String>[];
    for (final e in widget.to.entries) {
      try {
        await Bumps.instance.send(e.key, bump.withSender());
      } catch (_) {
        failed.add(e.value);
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (failed.length == widget.to.length) {
      setState(() => _error = 'Nem sikerült elküldeni (lehet, hogy kikapcsolta a bumpokat).');
      return;
    }
    Navigator.pop(context);
    playEffect(context, bump.show); // a küldő is lássa, mit küldött
    messenger.showSnackBar(SnackBar(
      content: Text(failed.isEmpty ? 'Bump elküldve! 👋' : 'Elküldve, kivéve: ${failed.join(', ')} (nem fogad most bumpot)'),
    ));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder?.cancel();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recording = _recorder != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Bump: ${widget.to.values.join(', ')}', style: Theme.of(context).textTheme.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (widget.event != null) Text('📅 ${widget.event!.title}', style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Üzenet (pl. Ne felejtsd a pizzát! 🍕)', counterText: ''),
            ),
            const SizedBox(height: 8),
            // Matrica vagy saját kép/GIF
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final s in bumpStickers)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() {
                        _sticker = s;
                        _image = null;
                      }),
                      child: Container(
                        width: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: _image == null && _sticker == s ? AppColors.primary.withValues(alpha: 0.18) : null,
                        ),
                        child: Text(s, style: const TextStyle(fontSize: 30)),
                      ),
                    ),
                ],
              ),
            ),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.gif_box_outlined),
                  label: Text(_image == null ? 'Kép / GIF' : 'Másik kép'),
                ),
                if (_image != null) ...[
                  const SizedBox(width: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(base64Decode(_image!), width: 44, height: 44, fit: BoxFit.cover, gaplessPlayback: true),
                  ),
                  IconButton(tooltip: 'Kép törlése', icon: const Icon(Icons.close), onPressed: () => setState(() => _image = null)),
                ],
              ],
            ),
            const SizedBox(height: 8),
            // Hangüzenet
            Row(
              children: [
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(backgroundColor: recording ? Colors.red.shade100 : null),
                  onPressed: _toggleRecording,
                  icon: Icon(recording ? Icons.stop_circle_outlined : Icons.mic_none),
                  label: Text(recording
                      ? 'Leállítás (${_recorder!.elapsed.inSeconds}/${Bumps.maxVoice.inSeconds} mp)'
                      : _voice == null
                          ? 'Hangüzenet'
                          : 'Újra felveszem'),
                ),
                if (_voice != null && !recording) ...[
                  const SizedBox(width: 8),
                  const Text('🎙️ kész'),
                  IconButton(tooltip: 'Hang törlése', icon: const Icon(Icons.close), onPressed: () => setState(() => _voice = null)),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text('Effekt', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in BumpEffect.values)
                  ChoiceChip(label: Text('${e.emoji} ${e.label}'), selected: _effect == e, onSelected: (_) => setState(() => _effect = e)),
              ],
            ),
            TextButton.icon(
              onPressed: () => playEffect(context, EffectShow(
                effect: _effect,
                image: _image == null ? null : base64Decode(_image!),
                sticker: _image == null ? _sticker : null,
                caption: 'Így fogja látni 👀',
              )),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Előnézet'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w600)),
              ),
            FilledButton.icon(
              onPressed: _busy || recording ? null : _send,
              icon: const Text('👋'),
              label: const Text('Bump küldése'),
            ),
          ],
        ),
      ),
    );
  }
}

extension on Bump {
  /// A küldő azonosítója a szolgáltatásból kerül bele.
  Bump withSender() => Bump(
        fromUid: Bumps.instance.myUid ?? '',
        fromName: fromName,
        text: text,
        effect: effect,
        sticker: sticker,
        image: image,
        audio: audio,
        audioMime: audioMime,
        eventId: eventId,
        eventTitle: eventTitle,
      );
}

/// Bump-beállítások a Beállításokban: fogadás ki/be, animációk ki/be.
class BumpSettingsCard extends StatefulWidget {
  const BumpSettingsCard({super.key});

  @override
  State<BumpSettingsCard> createState() => _BumpSettingsCardState();
}

class _BumpSettingsCardState extends State<BumpSettingsCard> {
  bool? _receive;

  @override
  void initState() {
    super.initState();
    if (Bumps.instance.ready) {
      Bumps.instance.settings().then((s) {
        if (mounted) setState(() => _receive = !s.off);
      }).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Card(
      child: Column(
        children: [
          if (Bumps.instance.ready)
            SwitchListTile(
              secondary: const IconTile(Icons.waving_hand_outlined),
              title: const Text('Bumpok fogadása', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Ha kikapcsolod, a barátaid nem tudnak bumpolni. Egy-egy barátot a Barátok fülön is némíthatsz.'),
              value: _receive ?? true,
              onChanged: _receive == null
                  ? null
                  : (on) async {
                      setState(() => _receive = on);
                      try {
                        await Bumps.instance.setOff(!on);
                      } catch (_) {
                        if (mounted) setState(() => _receive = !on);
                      }
                    },
            ),
          SwitchListTile(
            secondary: const IconTile(Icons.auto_awesome_outlined),
            title: const Text('Animációk lejátszása', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Konfetti, tűzijáték, felugró képek a bumpoknál.'),
            value: store.effectsOn,
            onChanged: store.setEffectsOn,
          ),
        ],
      ),
    );
  }
}
