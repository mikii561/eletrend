import 'package:intl/intl.dart';

import 'models.dart';

/// A felhasználó neve a költségmegosztásban.
const me = 'Én';

/// Egy utalás a végelszámolásban.
class Transfer {
  const Transfer(this.from, this.to, this.amount);

  final String from;
  final String to;
  final int amount;
}

String formatFt(int amount) => '${NumberFormat.decimalPattern('hu').format(amount)} Ft';

/// Költségmegosztás egy programon: ki mennyit fizetett, ki kinek tartozik.
class CostSplit {
  CostSplit(this.event);

  final Event event;

  /// Akik részt vesznek: a felhasználó és a meghívottak, plusz bárki, aki egy kiadásban szerepel.
  List<String> get people => {
        me,
        ...event.invited,
        for (final x in event.expenses) ...[x.payer, ...x.shares],
      }.toList();

  int get total => event.expenses.fold(0, (sum, x) => sum + x.amount);

  /// Személyenként: mennyivel fizetett többet (+) vagy kevesebbet (−) a ráeső résznél.
  /// A kerekítésből adódó pár forintot a lista elején állók viselik, így a végösszeg pontosan 0.
  Map<String, int> balances() {
    final result = {for (final p in people) p: 0};
    for (final x in event.expenses) {
      final shares = x.shares.isEmpty ? [x.payer] : x.shares;
      final each = x.amount ~/ shares.length;
      var rest = x.amount - each * shares.length;
      result[x.payer] = result[x.payer]! + x.amount;
      for (final s in shares) {
        final extra = rest > 0 ? 1 : 0;
        rest -= extra;
        result[s] = result[s]! - each - extra;
      }
    }
    return result;
  }

  /// A legkevesebb utalás, amivel mindenki kvittel: mindig a legnagyobb adós fizet
  /// a legnagyobb hitelezőnek.
  List<Transfer> settle() {
    final debtors = [for (final e in balances().entries) if (e.value < 0) MapEntry(e.key, -e.value)];
    final creditors = [for (final e in balances().entries) if (e.value > 0) MapEntry(e.key, e.value)];
    final result = <Transfer>[];
    while (debtors.isNotEmpty && creditors.isNotEmpty) {
      debtors.sort((a, b) => b.value.compareTo(a.value));
      creditors.sort((a, b) => b.value.compareTo(a.value));
      final d = debtors.first;
      final c = creditors.first;
      final amount = d.value < c.value ? d.value : c.value;
      result.add(Transfer(d.key, c.key, amount));
      debtors[0] = MapEntry(d.key, d.value - amount);
      creditors[0] = MapEntry(c.key, c.value - amount);
      debtors.removeWhere((e) => e.value == 0);
      creditors.removeWhere((e) => e.value == 0);
    }
    return result;
  }
}
