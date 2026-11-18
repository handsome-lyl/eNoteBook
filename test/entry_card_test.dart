import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:study_notebook/models/entry.dart';
import 'package:study_notebook/widgets/entry_card.dart';

void main() {
  testWidgets('EntryCard 点击会触发回调', (WidgetTester tester) async {
    var tapped = false;
    final entry = Entry(
      id: 'test-1',
      kind: EntryKind.textbook,
      title: '测试教材',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              height: 240,
              child: EntryCard(
                entry: entry,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('测试教材'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });
}
