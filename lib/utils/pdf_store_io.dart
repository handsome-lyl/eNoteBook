import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// 把 PDF 文件保存到应用文档目录，返回可持久化的文件路径。
Future<String?> savePdf(String entryId, Uint8List bytes) async {
  final dir = await getApplicationDocumentsDirectory();
  final pdfDir = Directory('${dir.path}${Platform.pathSeparator}pdfs');
  if (!await pdfDir.exists()) {
    await pdfDir.create(recursive: true);
  }
  final file = File('${pdfDir.path}${Platform.pathSeparator}$entryId.pdf');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

/// 原生平台直接按文件路径打开，不需要把字节读回内存。
Future<Uint8List?> loadPdfBytes(String? token) async => null;

Future<void> removePdf(String? token) async {
  if (token == null || token.isEmpty) return;
  try {
    final file = File(token);
    if (await file.exists()) await file.delete();
  } catch (_) {
    // 文件已不存在时忽略
  }
}
