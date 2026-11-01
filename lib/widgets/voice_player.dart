import '../l10n/l10n.dart';

import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text;

import '../l10n/text.dart';

/// Hangüzenet lejátszása (böngészőben data: címről, telefonon a memóriából).
class VoicePlayer extends StatefulWidget {
  const VoicePlayer({super.key, required this.audio, required this.mime, this.autoplay = false});

  /// A hang base64-ben.
  final String audio;
  final String mime;
  final bool autoplay;

  @override
  State<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<VoicePlayer> {
  AudioPlayer? _player;
  StreamSubscription<void>? _done;
  bool _playing = false;

  AudioPlayer get _ensurePlayer {
    final player = _player ??= AudioPlayer();
    _done ??= player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
    return player;
  }

  @override
  void initState() {
    super.initState();
    if (widget.autoplay) WidgetsBinding.instance.addPostFrameCallback((_) => _toggle());
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player?.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }
    setState(() => _playing = true);
    try {
      final source = kIsWeb
          ? UrlSource('data:${widget.mime};base64,${widget.audio}')
          : BytesSource(base64Decode(widget.audio), mimeType: widget.mime);
      await _ensurePlayer.play(source);
    } catch (e) {
      if (!mounted) return;
      setState(() => _playing = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nem sikerült lejátszani a hangot.')));
    }
  }

  @override
  void dispose() {
    _done?.cancel();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FilledButton.tonalIcon(
    onPressed: _toggle,
    icon: Icon(_playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
    label: Text(_playing ? tr('Leállítás') : tr('Hangüzenet lejátszása')),
  );
}
