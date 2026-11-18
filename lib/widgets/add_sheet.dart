import 'package:flutter/material.dart';

/// 底部「＋」弹出的三个操作
enum AddAction { textbook, note, notebook }

/// 点击底部加号后弹出的操作面板，顺序与设计图一致。
Future<AddAction?> showAddSheet(BuildContext context) {
  return showModalBottomSheet<AddAction>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.auto_stories_outlined),
              title: const Text('添加教材'),
              onTap: () => Navigator.of(sheetContext).pop(AddAction.textbook),
            ),
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
              title: const Text('添加单页'),
              onTap: () => Navigator.of(sheetContext).pop(AddAction.note),
            ),
            ListTile(
              leading: const Icon(Icons.library_add_outlined),
              title: const Text('新建笔记本'),
              onTap: () => Navigator.of(sheetContext).pop(AddAction.notebook),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
