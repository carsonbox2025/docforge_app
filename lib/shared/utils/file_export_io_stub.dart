import 'dart:typed_data';

/// Stub — 非 IO 平台不会调用此方法
Future<void> writeFile(String path, Uint8List bytes) async {
  throw UnsupportedError('writeFile is only available on io platforms');
}
