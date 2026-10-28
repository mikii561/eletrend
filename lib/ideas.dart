import 'dart:math';

/// Mire jó egy ötlet; ezekkel lehet szűrni.
enum IdeaTag {
  inside('🏠 Bent'),
  outside('🌳 Kint'),
  cheap('💸 Olcsó'),
  active('⚡ Aktív'),
  chill('🛋️ Lazulós');

  const IdeaTag(this.label);

  final String label;
}

class Idea {
  const Idea(this.emoji, this.title, this.text, this.tags);

  final String emoji;
  final String title;
  final String text;
  final Set<IdeaTag> tags;
}

const _i = IdeaTag.inside;
const _o = IdeaTag.outside;
const _c = IdeaTag.cheap;
const _a = IdeaTag.active;
const _l = IdeaTag.chill;

/// Programötletek, ha nem tudjátok, mit csináljatok.
const ideas = [
  Idea('🎬', 'Mozi', 'Nézzétek meg a legújabb filmet, utána egy közös vacsora.', {_i, _l}),
  Idea('🎳', 'Bowling', 'Pár kör bowling, a vesztes fizeti az üdítőt.', {_i, _a}),
  Idea('🥾', 'Túra', 'Egy könnyű félnapos túra a közelben, uzsonnával a csúcson.', {_o, _a, _c}),
  Idea('🎲', 'Társasjáték-est', 'Mindenki hoz egy játékot és egy nasit.', {_i, _l, _c}),
  Idea('🍝', 'Közös főzés', 'Válasszatok egy receptet, és főzzétek meg együtt.', {_i, _c}),
  Idea('🧺', 'Piknik', 'Pokróc, szendvicsek, egy jó park.', {_o, _l, _c}),
  Idea('🚴', 'Biciklitúra', 'Tekerjetek el egy kilátóhoz vagy egy tóhoz.', {_o, _a, _c}),
  Idea('🎤', 'Karaoke', 'A legrosszabb előadó választja a következő dalt.', {_i}),
  Idea('🧩', 'Szabadulószoba', 'Egy óra, egy szoba, egy csapat.', {_i, _a}),
  Idea('🏊', 'Strand vagy fürdő', 'Egy egész napos csobbanás.', {_o, _l}),
  Idea('☕', 'Kávézás', 'Próbáljatok ki egy új kávézót.', {_i, _l, _c}),
  Idea('🎨', 'Kreatív délután', 'Festés, agyagozás vagy egy workshop.', {_i, _l}),
  Idea('🏐', 'Röplabda vagy foci', 'Egy kis mozgás a parkban.', {_o, _a, _c}),
  Idea('🎮', 'Videojáték-est', 'Csapatjáték, pizza, éjfélig.', {_i, _l, _c}),
  Idea('🌄', 'Napfelkelte-nézés', 'Korán kelni nehéz, de megéri.', {_o, _c}),
  Idea('🍕', 'Pizza-teszt', 'Mindenki ajánl egy pizzázót, pontozzátok őket.', {_i, _l}),
  Idea('🎭', 'Színház', 'Egy vígjáték vagy egy improvizációs előadás.', {_i, _l}),
  Idea('🧗', 'Falmászás', 'Kezdőknek is van oktatás.', {_i, _a}),
  Idea('🛶', 'Kenuzás', 'Egy délután a vízen.', {_o, _a}),
  Idea('🌌', 'Csillagnézés', 'Menjetek ki a városból egy tiszta éjszakán.', {_o, _l, _c}),
  Idea('🍰', 'Sütés', 'Süssetek valamit, amit még sosem.', {_i, _c}),
  Idea('🏛️', 'Múzeum', 'Sok helyen van ingyenes nap.', {_i, _c, _l}),
  Idea('🎾', 'Tenisz vagy pingpong', 'Páros meccs, kieséses rendszerben.', {_o, _a}),
  Idea('📸', 'Fotóséta', 'Mindenki 10 képet készít egy témára, aztán szavaztok.', {_o, _c}),
  Idea('🍷', 'Borkóstoló', 'Mindenki hoz egy üveget, vakon kóstoltok.', {_i, _l}),
  Idea('🧘', 'Közös jóga', 'Egy online óra a nappaliban vagy a parkban.', {_i, _a, _c}),
  Idea('🎡', 'Vidámpark', 'Egy nap, amikor újra gyerekek vagytok.', {_o, _a}),
  Idea('🎧', 'Koncert', 'Nézzetek meg egy helyi zenekart.', {_i, _l}),
  Idea('🧶', 'Barkácsolás', 'Készítsetek valamit, amit haza is vihettek.', {_i, _c, _l}),
  Idea('🏕️', 'Sátrazás', 'Egy éjszaka a természetben, tábortűzzel.', {_o, _a}),
  Idea('🎯', 'Darts vagy biliárd', 'Egy kocsma, egy verseny.', {_i, _l}),
  Idea('🚶', 'Városi felfedezés', 'Sétáljatok egy olyan kerületben, ahol még nem jártatok.', {_o, _c, _a}),
  Idea('📚', 'Könyvklub', 'Olvassátok el ugyanazt a könyvet, aztán beszéljétek meg.', {_i, _c, _l}),
  Idea('🍜', 'Új konyha', 'Egy étterem olyan konyhával, amit még nem próbáltatok.', {_i}),
  Idea('⛸️', 'Korcsolya', 'Télen jégpálya, nyáron görkori.', {_o, _a}),
  Idea('🎉', 'Tematikus buli', 'Mindenki beöltözik egy témára.', {_i}),
];

/// Véletlen ötlet a szűrőknek megfelelően; nem adja ugyanazt kétszer egymás után.
Idea? randomIdea(Set<IdeaTag> filters, {Idea? not, Random? random}) {
  final pool = ideas.where((i) => i.tags.containsAll(filters) && i != not).toList();
  if (pool.isEmpty) return filters.isEmpty ? null : (ideas.where((i) => i.tags.containsAll(filters)).firstOrNull);
  return pool[(random ?? Random()).nextInt(pool.length)];
}
