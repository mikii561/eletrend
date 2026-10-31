/// Egy sablonban lévő cél beállításai.
class HabitSpec {
  const HabitSpec(this.name, {this.perWeek, this.target = 1, this.unit = ''});

  final String name;
  final int? perWeek;
  final int target;
  final String unit;
}

/// Cél-csomag, ami egy koppintással felvehető.
class HabitPack {
  const HabitPack(this.emoji, this.title, this.text, this.habits);

  final String emoji;
  final String title;
  final String text;
  final List<HabitSpec> habits;
}

const habitPacks = [
  HabitPack('🌅', 'Reggeli rutin', 'Jó indulás minden napra.', [
    HabitSpec('💧 Egy pohár víz ébredés után'),
    HabitSpec('🛏️ Ágyazás'),
    HabitSpec('🤸 5 perc nyújtás'),
    HabitSpec('📝 A nap 3 legfontosabb dolga'),
  ]),
  HabitPack('💪', 'Egészség', 'Mozgás, víz, pihenés.', [
    HabitSpec('💧 Víz', target: 8, unit: 'pohár'),
    HabitSpec('🏋️ Edzés', perWeek: 3),
    HabitSpec('🚶 Séta', target: 30, unit: 'perc'),
    HabitSpec('😴 Lefekvés éjfél előtt'),
  ]),
  HabitPack('🧠', 'Fókusz és tanulás', 'Kevesebb képernyő, több figyelem.', [
    HabitSpec('📖 Olvasás', target: 10, unit: 'oldal'),
    HabitSpec('📵 Telefonmentes este'),
    HabitSpec('🎧 Tanulás (nyelv, tanfolyam)', perWeek: 4),
  ]),
  HabitPack('🧘', 'Nyugalom', 'Lassíts le egy kicsit.', [
    HabitSpec('🧘 5 perc meditáció'),
    HabitSpec('🌬️ Légzőgyakorlat'),
    HabitSpec('🙏 3 dolog, amiért hálás vagyok'),
    HabitSpec('🌳 Idő a szabadban', perWeek: 3),
  ]),
  HabitPack('💸', 'Pénzügyek', 'Rend a pénztárcában.', [
    HabitSpec('🧾 Kiadások felírása'),
    HabitSpec('☕ Nem vettem kávét útközben', perWeek: 4),
    HabitSpec('🐷 Félretettem valamennyit', perWeek: 1),
  ]),
];
