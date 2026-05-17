import 'dart:typed_data';

/// Stub — 非 Web 平台不会调用此方法
void downloadBlob(Uint8List bytes, String fileName) {
  throw UnsupportedError('downloadBlob is only available on web');
}
