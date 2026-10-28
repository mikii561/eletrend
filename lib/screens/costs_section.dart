import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../costs.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Költségek egy program részleteinél: kiadások és ki kinek mennyit utaljon.
class CostsSection extends StatelessWidget {
  const CostsSection({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final split = CostSplit(event);
    final transfers = split.settle();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle('Költségek', trailing: event.expenses.isEmpty ? null : formatFt(split.total)),
        Card(
          child: Column(
            children: [
              for (final x in event.expenses)
                ListTile(
                  leading: NameAvatar(x.payer),
                  title: Text(x.title.isEmpty ? 'Kiadás' : x.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${x.payer} fizette • ${x.shares.length} főre'),
                  trailing: Text(formatFt(x.amount), style: const TextStyle(fontWeight: FontWeight.w800)),
                  onTap: () => showExpenseEditor(context, event, existing: x),
                ),
              ListTile(
                leading: Icon(Icons.add_card_outlined, color: AppColors.primary),
                title: Text(event.expenses.isEmpty ? 'Ki mit fizetett? Írd fel!' : 'Új kiadás',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                onTap: () => showExpenseEditor(context, event),
              ),
            ],
          ),
        ),
        if (transfers.isNotEmpty) ...[
          const SizedBox(height: 4),
          Card(
            color: AppColors.primary.withValues(alpha: 0.10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: Text('Elszámolás', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  for (final t in transfers)
                    ListTile(
                      dense: true,
                      leading: Icon(Icons.east, color: AppColors.primary),
                      title: Text.rich(TextSpan(children: [
                        TextSpan(text: t.from, style: const TextStyle(fontWeight: FontWeight.w800)),
                        TextSpan(text: t.from == me ? ' utalj ' : ' utal '),
                        TextSpan(text: t.to == me ? 'neked' : t.to, style: const TextStyle(fontWeight: FontWeight.w800)),
                      ])),
                      trailing: Text(formatFt(t.amount), style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                ],
              ),
            ),
          ),
        ] else if (event.expenses.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Mindenki kvittel. 👌', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
          ),
      ],
    );
  }
}

Future<void> showExpenseEditor(BuildContext context, Event event, {Expense? existing}) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ExpenseEditor(store: StoreScope.of(context), event: event, existing: existing),
    );

class _ExpenseEditor extends StatefulWidget {
  const _ExpenseEditor({required this.store, required this.event, this.existing});

  final AppStore store;
  final Event event;
  final Expense? existing;

  @override
  State<_ExpenseEditor> createState() => _ExpenseEditorState();
}

class _ExpenseEditorState extends State<_ExpenseEditor> {
  late final _people = CostSplit(widget.event).people;
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _amount = TextEditingController(text: widget.existing?.amount.toString());
  late String _payer = widget.existing?.payer ?? me;
  late final Set<String> _shares = {...(widget.existing?.shares ?? _people)};
  String? _error;

  void _save() {
    final amount = int.tryParse(_amount.text.replaceAll(RegExp(r'\D'), ''));
    if (amount == null || amount <= 0) return setState(() => _error = 'Írd be az összeget');
    if (_shares.isEmpty) return setState(() => _error = 'Válaszd ki, kik között oszlik meg');
    final x = widget.existing ??
        Expense(id: newId(), title: '', amount: 0, payer: me, shares: []);
    x
      ..title = _title.text.trim()
      ..amount = amount
      ..payer = _payer
      ..shares = [for (final p in _people) if (_shares.contains(p)) p];
    if (!widget.event.expenses.contains(x)) widget.event.expenses.add(x);
    widget.store.saveEvent(widget.event);
    Navigator.pop(context);
  }

  void _delete() {
    widget.event.expenses.remove(widget.existing);
    widget.store.saveEvent(widget.event);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
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
            Text(widget.existing == null ? 'Új kiadás' : 'Kiadás szerkesztése', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Mire?', hintText: 'pl. mozijegyek, pizza'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: 'Összeg', suffixText: 'Ft', errorText: _error),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 16),
            Text('Ki fizette?', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in _people)
                  ChoiceChip(
                    avatar: NameAvatar(p, radius: 11),
                    label: Text(p),
                    selected: _payer == p,
                    onSelected: (_) => setState(() => _payer = p),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Kik között osszuk el?', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in _people)
                  FilterChip(
                    label: Text(p),
                    selected: _shares.contains(p),
                    onSelected: (on) => setState(() => on ? _shares.add(p) : _shares.remove(p)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (widget.existing != null) ...[
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
