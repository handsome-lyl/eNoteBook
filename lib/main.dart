import 'package:flutter/material.dart';

import 'pages/home_page.dart';
import 'store/app_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppStore store;
  try {
    store = await AppStore.open();
  } catch (_) {
    store = AppStore();
  }
  runApp(StudyNotebookApp(store: store));
}

class StudyNotebookApp extends StatefulWidget {
  const StudyNotebookApp({super.key, this.store});

  /// 由 [main] 传入已加载本地数据的仓库；测试中不传则使用内存仓库。
  final AppStore? store;

  @override
  State<StudyNotebookApp> createState() => _StudyNotebookAppState();
}

class _StudyNotebookAppState extends State<StudyNotebookApp> {
  late final AppStore _store = widget.store ?? AppStore();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '电子笔记本',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1565C0),
      ),
      home: HomePage(store: _store),
    );
  }
}
