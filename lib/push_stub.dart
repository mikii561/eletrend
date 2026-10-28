// Nem böngészőben nincs webes push (Androidon a helyi értesítések mennek).
bool get supported => false;
bool get standalone => false;
bool get ios => false;
String get permission => 'unsupported';

Future<String?> token(String vapidKey, {required bool ask}) async => null;
