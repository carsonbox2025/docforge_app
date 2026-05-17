import 'dart:io';
import 'dart:typed_data';

/// IO 平台实现：直接写文件
Future<void> writeFile(String path, Uint8List bytes) async {
  await File(path).writeAsBytes(bytes);
}
