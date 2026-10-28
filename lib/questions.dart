/// Napi naplókérdések. Minden napra jut egy, de cserélni is lehet.
const dailyQuestions = [
  'Mi volt ma a legviccesebb pillanat?',
  'Kinek köszönnél meg ma valamit, és miért?',
  'Mi az, amire ma büszke vagy?',
  'Mit tanultál ma?',
  'Mi okozott ma meglepetést?',
  'Mi volt ma a legfinomabb, amit ettél?',
  'Melyik beszélgetés esett ma a legjobban?',
  'Mi az, amit holnap másképp csinálnál?',
  'Mi adott ma energiát?',
  'Mi szívta el ma az energiádat?',
  'Mit csinálnál, ha holnap szabadnapod lenne?',
  'Milyen dal illene a mai napodhoz?',
  'Mi volt ma a legszebb látvány?',
  'Kivel töltenél szívesen több időt mostanában?',
  'Mi az, ami ma jobban sikerült, mint vártad?',
  'Milyen kis öröm ért ma?',
  'Mire vársz a legjobban a következő héten?',
  'Mi foglalkoztat mostanában a legtöbbet?',
  'Mi volt ma a nap legnehezebb része, és hogyan kezelted?',
  'Kinek okoztál ma örömet?',
  'Ha a mai napnak címe lenne, mi lenne az?',
  'Mi az, amit ma először csináltál?',
  'Melyik célodra vagy mostanában büszke?',
  'Mi az, amit szeretnél elengedni?',
  'Mit mondanál a tegnapi önmagadnak?',
  'Mi nevettetett meg ma?',
  'Melyik helyen érezted ma a legjobban magad?',
  'Mi az, amit ma csak magadért tettél?',
  'Milyen álmod vagy terved jutott ma eszedbe?',
  'Mi az a három szó, ami leírja a mai napodat?',
  'Mit csinálnál szívesen újra a mai napból?',
  'Milyen apróság tette jobbá a napodat?',
];

/// A naphoz tartozó kérdés (minden napra ugyanaz, így újranyitáskor sem változik).
String questionFor(DateTime day) {
  final dayOfYear = day.difference(DateTime(day.year)).inDays;
  return dailyQuestions[(dayOfYear + day.year) % dailyQuestions.length];
}

/// A következő kérdés a listában a „Másik kérdés” gombhoz.
String nextQuestion(String current) {
  final i = dailyQuestions.indexOf(current);
  return dailyQuestions[(i + 1) % dailyQuestions.length];
}
