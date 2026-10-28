import 'package:flutter/material.dart';

/// Az app ki-be kapcsolható részei, hogy mindenki csak azt lássa, amit használ.
enum Feature {
  checkIn('„Hogy vagy most?” kártya', 'Gyors hangulat napközben a Ma képernyőn.', Icons.mood_outlined),
  memories('Egy éve ezen a napon', 'Régi bejegyzéseid felidézése a Ma képernyőn.', Icons.history_outlined),
  weather('Időjárás', 'Előrejelzés a helyszínnel megadott programoknál.', Icons.wb_cloudy_outlined),
  community('Közösségi ötletek', 'Mások programötletei, értékelés és megosztás.', Icons.lightbulb_outline),
  challenges('Közös kihívások', 'Kihívások a barátaiddal, ranglistával.', Icons.flag_outlined),
  bumps('Bumpok', 'Üzenetek, képek, hangüzenetek és effektek a barátoktól.', Icons.waving_hand_outlined),
  badges('Jelvények', 'Elismerések és ünneplés a teljesítményeidért.', Icons.emoji_events_outlined),
  breathing('Légzőgyakorlat', 'Egyszerű légzésidőzítő a Célok képernyőn.', Icons.self_improvement_outlined);

  const Feature(this.title, this.description, this.icon);

  final String title;
  final String description;
  final IconData icon;
}
