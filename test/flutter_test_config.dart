import 'dart:async';

import 'package:eletrend/l10n/l10n.dart';
import 'package:eletrend/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Minden teszt magyarul fut (a tesztek magyar szövegeket várnak); az app alapnyelve angol,
/// ezt a tesztek külön, kifejezetten állítják be.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppStore.defaultLanguage = AppLanguage.hu;
  await initializeDateFormatting('hu');
  await initializeDateFormatting('en');
  setUp(() {
    L10n.lang = AppLanguage.hu;
    AppStore.defaultLanguage = AppLanguage.hu;
  });
  await testMain();
}
