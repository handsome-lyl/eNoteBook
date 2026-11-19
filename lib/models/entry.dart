import 'dart:typed_data';

/// 条目类型：教材、笔记本、单页笔记
enum EntryKind { textbook, notebook, note }

/// 应用内的一条数据：教材 / 笔记本 / 单页笔记
class Entry {
  Entry({
    required this.id,
    required this.kind,
    required this.title,
    this.content = '',
    List<Uint8List>? images,
    this.parentId,
    this.pdfPath,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : images = images ?? <Uint8List>[],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final EntryKind kind;

  /// 名称，创建时由用户输入
  String title;

  /// 教材为导入的纯文本；单页笔记为正文
  String content;

  /// 单页笔记中插入的图片（内存中保存原始字节）
  final List<Uint8List> images;

  /// 单页笔记的归属：某个笔记本或教材的 id，null 表示未归属
  String? parentId;

  /// 导入的 PDF 教材文件位置（Android 为本地文件路径，Web 为会话内缓存标记）
  String? pdfPath;

  final DateTime createdAt;
  DateTime updatedAt;

  bool get isNote => kind == EntryKind.note;

  bool get isContainer =>
      kind == EntryKind.notebook || kind == EntryKind.textbook;

  /// 是否按 PDF 原样渲染
  bool get hasPdf => pdfPath != null && pdfPath!.isNotEmpty;
}

extension EntryKindText on EntryKind {
  String get label => switch (this) {
        EntryKind.textbook => '教材',
        EntryKind.notebook => '笔记本',
        EntryKind.note => '单页笔记',
      };
}
