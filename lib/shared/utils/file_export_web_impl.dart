// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// Web 平台实现：通过 Blob + ObjectURL + AnchorElement 触发浏览器下载
void downloadBlob(Uint8List bytes, String safeName) {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', safeName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
