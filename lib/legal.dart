import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'l10n/l10n.dart';

/// A weboldalon lévő jogi oldalak (a `web/` mappából kerülnek a GitHub Pages-re).
enum LegalPage {
  privacy('privacy.html'),
  terms('terms.html');

  const LegalPage(this.file);

  final String file;
}

const siteUrl = 'https://mikii561.github.io/eletrend/';

/// Az oldal címe az app mostani nyelvén (az oldal a `lang` alapján ugyanazt a nyelvet mutatja).
Uri legalUri(LegalPage page) => Uri.parse('$siteUrl${page.file}?lang=${L10n.code}');

/// Megnyitás böngészőben. Tesztben cserélhető.
@visibleForTesting
Future<bool> Function(Uri uri) legalLauncher = (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

Future<bool> openLegal(LegalPage page) async {
  try {
    return await legalLauncher(legalUri(page));
  } catch (_) {
    return false;
  }
}
