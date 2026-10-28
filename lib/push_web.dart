import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// A web/push.js függvényei (csak böngészőben).
JSObject? get _js => globalContext['eletrendPush'] as JSObject?;

bool _call(String method) => (_js?.callMethod<JSBoolean>(method.toJS))?.toDart ?? false;

bool get supported => _call('supported');
bool get standalone => _call('standalone');
bool get ios => _call('ios');
String get permission => (_js?.callMethod<JSString>('permission'.toJS))?.toDart ?? 'unsupported';

Future<String?> token(String vapidKey, {required bool ask}) async {
  final js = _js;
  if (js == null) return null;
  final result = await js.callMethod<JSPromise<JSString?>>('token'.toJS, vapidKey.toJS, ask.toJS).toDart;
  return result?.toDart;
}
