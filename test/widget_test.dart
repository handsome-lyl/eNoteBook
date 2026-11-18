import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:study_notebook/main.dart';
import 'package:study_notebook/pages/textbook_reader_page.dart';

void main() {
  testWidgets('主页可以渲染示例条目', (WidgetTester tester) async {
    await tester.pumpWidget(const StudyNotebookApp());
    await tester.pumpAndSettle();

    expect(find.text('课程笔记'), findsWidgets);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('宽屏显示左侧导航栏', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const StudyNotebookApp());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('列表'), findsOneWidget);
  });

  testWidgets('窄屏显示底部加号', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const StudyNotebookApp());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(BottomAppBar), findsOneWidget);
  });

  testWidgets('点击加号弹出三项操作', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const StudyNotebookApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('添加教材'), findsOneWidget);
    expect(find.text('添加单页'), findsOneWidget);
    expect(find.text('新建笔记本'), findsOneWidget);
  });

  testWidgets('点击教材卡片进入阅读页', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const StudyNotebookApp());
    await tester.pumpAndSettle();

    final card = find.text('移动软件开发 · 第九章动画');
    expect(card, findsOneWidget);
    await tester.tapAt(tester.getCenter(card));
    await tester.pumpAndSettle();

    expect(find.byType(TextbookReaderPage), findsOneWidget);
    expect(find.text('移动软件开发 · 第九章动画'), findsWidgets);
  });
}
