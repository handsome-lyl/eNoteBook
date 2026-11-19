import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:study_notebook/store/app_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('数据写入本地存储后重新打开仍能恢复', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final store = await AppStore.open();
    expect(store.sortedEntries(), isNotEmpty, reason: '首次启动应写入示例数据');

    final note = store.createNote('持久化测试', content: '第一段![img0]第二段');
    note.images.add(Uint8List.fromList(<int>[1, 2, 3]));
    await store.persist();

    final reopened = await AppStore.open();
    final restored = reopened.byId(note.id);
    expect(restored, isNotNull);
    expect(restored!.title, '持久化测试');
    expect(restored.content, '第一段![img0]第二段');
    expect(restored.images.single, <int>[1, 2, 3]);
    expect(reopened.notes.map((e) => e.title), contains('持久化测试'));
  });

  test('删除教材时其下笔记一并从本地移除', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final store = await AppStore.open();
    final notebook = store.createNotebook('临时笔记本');
    final note = store.createNote('临时笔记', parentId: notebook.id);
    await store.persist();

    store.deleteEntry(notebook);
    await store.persist();

    final reopened = await AppStore.open();
    expect(reopened.byId(notebook.id), isNull);
    expect(reopened.byId(note.id), isNull);
  });
}
