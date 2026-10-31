import 'package:flutter/material.dart';

import 'models.dart';

/// Hová visz egy tipp gombja.
enum TipAction { memories, findTime, calendar, friends, homeCards, privacy }

/// Egy rövid „Tudtad?” tipp a Főoldalon.
class Tip {
  const Tip(this.id, this.icon, this.text, {this.actionLabel, this.action});

  final String id;
  final IconData icon;
  final String text;
  final String? actionLabel;
  final TipAction? action;
}

const tips = [
  Tip(
    'memories',
    Icons.photo_library_outlined,
    'Egy közös program után tölts fel fotókat: később emlékként visszajönnek a Főoldalra.',
    actionLabel: 'Példa',
    action: TipAction.memories,
  ),
  Tip(
    'findTime',
    Icons.event_available_outlined,
    'Nem tudjátok, mikor jó mindenkinek? A „Közös idő” megkeresi, mikor ér rá mindenki.',
    actionLabel: 'Kipróbálom',
    action: TipAction.findTime,
  ),
  Tip(
    'calendarTap',
    Icons.touch_app_outlined,
    'A Naptárban egy üres időpontra koppintva rögtön ott kezdődik az új bejegyzés.',
    actionLabel: 'Naptár',
    action: TipAction.calendar,
  ),
  Tip(
    'scheduleTask',
    Icons.view_timeline_outlined,
    'Egy feladatot be is oszthatsz a naptárba: így időt foglalsz rá, és a teendő a beosztásodban is ott lesz.',
  ),
  Tip(
    'nudge',
    Icons.waving_hand_outlined,
    'Rég találkoztatok? Egy barátságos bökés a Barátok fülön emlékezteti.',
    actionLabel: 'Barátok',
    action: TipAction.friends,
  ),
  Tip(
    'groups',
    Icons.group_outlined,
    'Csoportokkal (pl. „Foci csapat”) egy koppintással hívhatsz meg többeket.',
    actionLabel: 'Barátok',
    action: TipAction.friends,
  ),
  Tip(
    'homeCards',
    Icons.dashboard_customize_outlined,
    'A Főoldal kártyáit átrendezheted és elrejtheted, hogy csak az legyen itt, ami neked kell.',
    actionLabel: 'Testreszabás',
    action: TipAction.homeCards,
  ),
  Tip(
    'privacy',
    Icons.lock_outline,
    'Te döntöd el, ki látja, mikor érsz rá. A programjaid részleteit soha senki.',
    actionLabel: 'Adatvédelem',
    action: TipAction.privacy,
  ),
  Tip(
    'status',
    Icons.circle_outlined,
    'Ma nyitott vagy egy programra? Állítsd be az állapotodat fent a Főoldalon, és a barátaid látni fogják.',
  ),
];

/// Hány naponta jöhet új tipp, és bezárás után mennyi ideig nem jön semmi.
const tipEveryDays = 2;

/// A mai tipp: a még be nem zártak közül, kétnaponta másik. Null, ha épp szünet van
/// (nemrég zárt be egyet), vagy már mindet látta.
Tip? pickTip({required Set<String> closed, DateTime? snoozeUntil, required DateTime now}) {
  if (snoozeUntil != null && now.isBefore(snoozeUntil)) return null;
  final open = tips.where((t) => !closed.contains(t.id)).toList();
  if (open.isEmpty) return null;
  final slot = startOfDay(now).difference(DateTime(2020)).inDays ~/ tipEveryDays;
  return open[slot % open.length];
}
