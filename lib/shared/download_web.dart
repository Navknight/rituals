// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<void> downloadImageWeb(String url, String filename) async {
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
}
