import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<void> downloadImageWeb(String url, String filename) async {
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body?.append(anchor as JSAny);
  anchor.click();
  anchor.remove();
}
