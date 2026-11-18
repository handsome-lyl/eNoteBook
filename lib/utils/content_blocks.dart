library;

/// 正文块模型：文本段 或 图片段。
///
/// 正文 content 字符串中用 `![img{N}]` 表示图片占位，
/// 其中 N 是图片在 images 列表中的索引。
/// 编辑器 UI 把 content 解析成 [ContentBlock] 列表渲染为混合视图，
/// 保存时再把块列表序列化为 content 字符串，保证索引与 images 对齐。

import 'dart:typed_data';

sealed class ContentBlock {
  const ContentBlock();
}

class TextBlock extends ContentBlock {
  TextBlock(this.text);
  String text;
}

class ImageBlock extends ContentBlock {
  ImageBlock(this.imageIndex);

  /// 对应 Entry.images 里的下标
  int imageIndex;
}

/// 把 content 字符串（含 ![img{N}] 标记）解析为块列表。
List<ContentBlock> parseContentBlocks(String content) {
  final List<ContentBlock> result = [];
  final imgRe = RegExp(r'!\[img(\d+)\]');
  int last = 0;
  for (final m in imgRe.allMatches(content)) {
    if (m.start > last) {
      final text = content.substring(last, m.start);
      if (text.isNotEmpty) result.add(TextBlock(text));
    }
    result.add(ImageBlock(int.parse(m.group(1)!)));
    last = m.end;
  }
  if (last < content.length) {
    final text = content.substring(last);
    if (text.isNotEmpty) result.add(TextBlock(text));
  }
  return result;
}

/// 把块列表序列化为 content 字符串。
/// 图片用 `![img{N}]` 内联标记，不加额外换行，保证与 [parseContentBlocks] 严格往返。
String serializeContentBlocks(List<ContentBlock> blocks) {
  final buf = StringBuffer();
  for (final b in blocks) {
    if (b is TextBlock) {
      buf.write(b.text);
    } else if (b is ImageBlock) {
      buf.write('![img${b.imageIndex}]');
    }
  }
  return buf.toString();
}

/// 删除 images 中索引 [removedIdx] 后，重排 blocks 中所有 ImageBlock 的索引。
void remapImageIndices(List<ContentBlock> blocks, int removedIdx) {
  for (final b in blocks) {
    if (b is ImageBlock && b.imageIndex > removedIdx) {
      b.imageIndex -= 1;
    }
  }
}

/// 从 [bytes] 拷贝出一个可编辑副本（避免直接修改 Entry.images 原始 bytes）。
List<Uint8List> cloneImages(List<Uint8List> images) {
  return images.map((e) => Uint8List.fromList(e)).toList();
}
