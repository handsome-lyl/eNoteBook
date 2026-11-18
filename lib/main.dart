import 'package:flutter/material.dart';

import 'pages/home_page.dart';

void main() {
  runApp(const StudyNotebookApp());
}

class StudyNotebookApp extends StatelessWidget {
  const StudyNotebookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '电子笔记本',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1565C0),
      ),
      home: const HomePage(),
    );
  }
}
