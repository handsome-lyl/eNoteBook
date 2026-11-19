import 'dart:convert';

import '../models/entry.dart';

/// Entry 与 JSON 的互转。
///
/// 图片以 Base64 字符串保存，这样整份数据可以序列化为一个字符串
/// 写入本地存储（Android 的 SharedPreferences / Web 的 localStorage）。
Map<String, dynamic> entryToJson(Entry entry) {
  return <String, dynamic>{
    'id': entry.id,
    'kind': entry.kind.name,
    'title': entry.title,
    'content': entry.content,
    'images': entry.images.map(base64Encode).toList(),
    'parentId': entry.parentId,
    'createdAt': entry.createdAt.toIso8601String(),
    'updatedAt': entry.updatedAt.toIso8601String(),
  };
}

Entry entryFromJson(Map<String, dynamic> json) {
  return Entry(
    id: json['id'] as String,
    kind: EntryKind.values.firstWhere(
      (kind) => kind.name == json['kind'],
      orElse: () => EntryKind.note,
    ),
    title: json['title'] as String? ?? '',
    content: json['content'] as String? ?? '',
    images: (json['images'] as List<dynamic>? ?? const <dynamic>[])
        .map((image) => base64Decode(image as String))
        .toList(),
    parentId: json['parentId'] as String?,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
  );
}

/// 把全部条目编码成单个 JSON 字符串。
String encodeEntries(List<Entry> entries) =>
    jsonEncode(entries.map(entryToJson).toList());

/// 解析 [encodeEntries] 生成的字符串；格式不合法时抛出 [FormatException]。
List<Entry> decodeEntries(String raw) {
  final data = jsonDecode(raw);
  if (data is! List) {
    throw const FormatException('条目数据格式错误');
  }
  return data
      .map((item) => entryFromJson(item as Map<String, dynamic>))
      .toList();
}
