import 'dart:typed_data';

/// Web 端把 PDF 字节保存在内存中（仅当前会话有效）。
final Map<String, Uint8List> _cache = <String, Uint8List>{};

Future<String?> savePdf(String entryId, Uint8List bytes) async {
  _cache[entryId] = bytes;
  return 'memory:$entryId';
}

Future<Uint8List?> loadPdfBytes(String? token) async {
  if (token == null || !token.startsWith('memory:')) return null;
  return _cache[token.substring('memory:'.length)];
}

Future<void> removePdf(String? token) async {
  if (token == null || !token.startsWith('memory:')) return;
  _cache.remove(token.substring('memory:'.length));
}
