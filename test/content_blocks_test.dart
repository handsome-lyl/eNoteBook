import 'package:flutter_test/flutter_test.dart';
import 'package:study_notebook/utils/content_blocks.dart';

void main() {
  test('解析纯文本为单个文本块', () {
    final blocks = parseContentBlocks('第一段文字');
    expect(blocks.length, 1);
    expect(blocks.first, isA<TextBlock>());
    expect((blocks.first as TextBlock).text, '第一段文字');
  });

  test('解析图片标记为图片块', () {
    final blocks = parseContentBlocks('前文![img0]后文');
    expect(blocks.length, 3);
    expect((blocks[0] as TextBlock).text, '前文');
    expect((blocks[1] as ImageBlock).imageIndex, 0);
    expect((blocks[2] as TextBlock).text, '后文');
  });

  test('多张图片按顺序解析', () {
    final blocks = parseContentBlocks('A![img0]B![img1]C');
    expect(blocks.length, 5);
    expect((blocks[1] as ImageBlock).imageIndex, 0);
    expect((blocks[3] as ImageBlock).imageIndex, 1);
  });

  test('序列化与解析严格往返，不引入多余换行', () {
    final original = <ContentBlock>[
      TextBlock('第一段'),
      ImageBlock(0),
      TextBlock('第二段'),
      ImageBlock(1),
      TextBlock('结尾'),
    ];
    final content = serializeContentBlocks(original);
    expect(content, '第一段![img0]第二段![img1]结尾');

    final parsed = parseContentBlocks(content);
    expect(serializeContentBlocks(parsed), content);
    expect((parsed[0] as TextBlock).text, '第一段');
    expect((parsed[2] as TextBlock).text, '第二段');
  });

  test('空文本块不生成多余块', () {
    final blocks = parseContentBlocks('');
    expect(blocks, isEmpty);
  });

  test('删除图片后索引正确重排', () {
    final blocks = <ContentBlock>[
      TextBlock('a'),
      ImageBlock(0),
      TextBlock('b'),
      ImageBlock(1),
      TextBlock('c'),
      ImageBlock(2),
    ];
    // 删除第 0 张图片后，原本的 1、2 号图片应变成 0、1
    blocks.removeAt(1);
    remapImageIndices(blocks, 0);
    final indices = blocks.whereType<ImageBlock>().map((b) => b.imageIndex).toList();
    expect(indices, <int>[0, 1]);
  });
}
