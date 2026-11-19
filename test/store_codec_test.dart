import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:study_notebook/models/entry.dart';
import 'package:study_notebook/store/store_codec.dart';

void main() {
  test('Entry 编码再解码后字段保持一致', () {
    final entry = Entry(
      id: 'e1',
      kind: EntryKind.textbook,
      title: '测试教材',
      content: '第一段![img0]第二段',
      images: <Uint8List>[Uint8List.fromList(<int>[0, 255, 1, 2])],
      parentId: 'p1',
    );

    final decoded = decodeEntries(encodeEntries(<Entry>[entry])).single;
    expect(decoded.id, entry.id);
    expect(decoded.kind, entry.kind);
    expect(decoded.title, entry.title);
    expect(decoded.content, entry.content);
    expect(decoded.parentId, entry.parentId);
    expect(decoded.images.single, <int>[0, 255, 1, 2]);
    expect(decoded.createdAt, entry.createdAt);
    expect(decoded.updatedAt, entry.updatedAt);
  });

  test('空列表可以正常往返', () {
    expect(decodeEntries(encodeEntries(<Entry>[])), isEmpty);
  });

  test('字段缺失时使用默认值', () {
    final decoded = entryFromJson(<String, dynamic>{'id': 'e2'});
    expect(decoded.kind, EntryKind.note);
    expect(decoded.title, '');
    expect(decoded.content, '');
    expect(decoded.images, isEmpty);
    expect(decoded.parentId, isNull);
  });
}
