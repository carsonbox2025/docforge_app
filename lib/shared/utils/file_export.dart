import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'file_export_io_stub.dart'
    if (dart.library.io) 'file_export_io_impl.dart' as io;
import 'file_export_web_stub.dart'
    if (dart.library.html) 'file_export_web_impl.dart' as web_dl;

class FileExporter {
  FileExporter._();

  static Future<ExportResult> saveAndOpen({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (kIsWeb) {
      web_dl.downloadBlob(bytes, fileName);
      return ExportResult(path: fileName, openResult: OpenResult(type: ResultType.done));
    }
    final dir = await getApplicationDocumentsDirectory();
    final safeName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final path = '${dir.path}/$safeName';
    await io.writeFile(path, bytes);

    final result = await OpenFilex.open(path);
    debugPrint('[FileExporter] open result: ${result.type} ${result.message}');
    return ExportResult(path: path, openResult: result);
  }

  static Future<String> saveAndShare({
    required Uint8List bytes,
    required String fileName,
    String? subject,
  }) async {
    if (kIsWeb) {
      web_dl.downloadBlob(bytes, fileName);
      return fileName;
    }
    final dir = await getTemporaryDirectory();
    final safeName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final path = '${dir.path}/$safeName';
    await io.writeFile(path, bytes);
    await Share.shareXFiles(
      [XFile(path)],
      subject: subject ?? fileName,
    );
    return path;
  }
}

class ExportResult {
  final String path;
  final OpenResult openResult;
  const ExportResult({required this.path, required this.openResult});
}
