import 'package:flutter/material.dart';

import '../models/entry.dart';

const Map<EntryKind, List<Color>> _coverGradients = <EntryKind, List<Color>>{
  EntryKind.textbook: <Color>[Color(0xFF1565C0), Color(0xFF42A5F5)],
  EntryKind.notebook: <Color>[Color(0xFF3949AB), Color(0xFF7986CB)],
  EntryKind.note: <Color>[Color(0xFF0277BD), Color(0xFF4FC3F7)],
};

IconData entryIcon(EntryKind kind) => switch (kind) {
      EntryKind.textbook => Icons.auto_stories_outlined,
      EntryKind.notebook => Icons.collections_bookmark_outlined,
      EntryKind.note => Icons.sticky_note_2_outlined,
    };

/// 条目封面。
///
/// 外层包了 Hero，卡片与详情页使用同一个 tag，
/// 点击卡片时封面会从列表“飞”到详情页顶部（教材 9.4：Hero 动画）。
class EntryCover extends StatelessWidget {
  const EntryCover({
    super.key,
    required this.entry,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(16)),
    this.iconSize = 40,
  });

  final Entry entry;
  final BorderRadius borderRadius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = _coverGradients[entry.kind]!;
    return Hero(
      tag: 'cover-${entry.id}',
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
          child: Center(
            child: Icon(entryIcon(entry.kind), size: iconSize, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
