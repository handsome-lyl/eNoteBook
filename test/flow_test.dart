import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:study_notebook/main.dart';

Finder dialogTextField(int index) {
  final fields = find
      .descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      )
      .evaluate()
      .toList();
  final all = find.byType(TextField).evaluate().toList();
  return find.byType(TextField).at(all.indexOf(fields[index]));
}

void main() {
  testWidgets('新建笔记本后卡片出现在主页', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const StudyNotebookApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建笔记本'));
    await tester.pumpAndSettle();

    await tester.enterText(dialogTextField(0), '实验笔记本');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('实验笔记本'), findsOneWidget);
  });

  testWidgets('搜索框按关键词过滤卡片', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const StudyNotebookApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '课程');
    await tester.pumpAndSettle();

    expect(find.text('课程笔记'), findsOneWidget);
    expect(find.text('移动软件开发 · 第九章动画'), findsNothing);
  });

  testWidgets('历史记录列出单页笔记', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const StudyNotebookApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CircleAvatar));
    await tester.pumpAndSettle();
    await tester.tap(find.text('历史记录'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('动画三要素'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('登录校验：空用户名与短密码不通过', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const StudyNotebookApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CircleAvatar));
    await tester.pumpAndSettle();
    await tester.tap(find.text('登录/注册'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('请输入用户名'),
      ),
      findsOneWidget,
    );

    await tester.enterText(dialogTextField(0), '张三');
    await tester.enterText(dialogTextField(1), '123');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('密码至少 6 位'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('登录成功后头像显示首字母', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const StudyNotebookApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CircleAvatar));
    await tester.pumpAndSettle();
    await tester.tap(find.text('登录/注册'));
    await tester.pumpAndSettle();

    await tester.enterText(dialogTextField(0), 'lisi');
    await tester.enterText(dialogTextField(1), '123456');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(CircleAvatar),
        matching: find.text('L'),
      ),
      findsOneWidget,
    );
  });
}
