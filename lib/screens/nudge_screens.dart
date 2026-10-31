import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../nudges.dart';
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

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Válassz egy szöveget, vagy írj sajátot.');
      return;
    }
    final store = StoreScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
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
        );
      } catch (err) {
        failed.add(e.value);
      }
    }
    if (!mounted) return;
    setState(() => _sending = false);
    if (failed.length == widget.to.length) {
      setState(() => _error = 'Nem ment ki. Lehet, hogy ma már elég bökést küldtél, vagy kikapcsolta őket.');
      return;
    }
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failed.isEmpty ? 'Elküldve.' : 'Elküldve, kivéve: ${failed.join(', ')} (napi keret vagy kikapcsolta).',
        ),
      ),
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
          Text('Bökés: ${widget.to.values.join(', ')}', style: Theme.of(context).textTheme.titleLarge),
          if (widget.eventTitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Program: ${widget.eventTitle}', style: TextStyle(color: AppColors.textMuted)),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (emoji, text) in nudgeTemplates)
                ActionChip(
                  label: Text('$emoji $text'),
                  onPressed: () => setState(() {
                    _emoji = emoji;
                    _text.text = text;
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
            decoration: InputDecoration(hintText: 'Vagy írd meg a sajátodat…', errorText: _error),
            onChanged: (_) => setState(() => _error = null),
          ),
          Text(
            'Naponta legfeljebb ${Nudges.dailyLimit} bökés mehet ugyanannak a barátnak, hogy ne legyen tolakodó.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: const Icon(Icons.waving_hand_outlined),
            label: Text(_sending ? 'Küldés…' : 'Bökés küldése'),
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
                  return const Padding(padding: EdgeInsets.all(16), child: ErrorState(text: 'Nem töltődtek be. Van internet?'));
                }
                if (!snap.hasData) return const Center(child: LoadingState());
                final list = snap.data!;
                if (list.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [EmptyState(emoji: '👋', text: 'Még nem bökött meg senki.')],
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final n in list)
                      Card(
                        child: ListTile(
                          leading: Text(n.emoji, style: const TextStyle(fontSize: 26)),
                          title: Text(n.text, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            [
                              n.fromName,
                              if (n.at != null) DateFormat('MMM d. HH:mm', 'hu').format(n.at!),
                              if (n.eventTitle != null) n.eventTitle!,
                            ].join(' · '),
                          ),
                          onTap: () => openNudge(context, n),
                          trailing: IconButton(
                            tooltip: 'Törlés',
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
Future<void> openNudge(BuildContext context, Nudge n) async {
  Nudges.instance.markSeen(n.id).catchError((_) {});
  final id = n.eventId;
  await Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => id == null ? const NudgeInboxScreen() : InviteScreen(eventId: id)));
}
