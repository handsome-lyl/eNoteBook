import 'package:flutter/material.dart';

import '../app_route.dart';
import '../models/entry.dart';
import '../store/app_store.dart';
import '../utils/format_time.dart';
import '../widgets/dialogs.dart';
import '../widgets/entry_cover.dart';
import 'note_editor_page.dart';

/// 教材阅读页：滚动阅读导入的 TXT 内容，并可在教材下添加单页笔记。
class TextbookReaderPage extends StatefulWidget {
  const TextbookReaderPage({
    super.key,
    required this.store,
    required this.textbook,
  });

  final AppStore store;
  final Entry textbook;

  @override
  State<TextbookReaderPage> createState() => _TextbookReaderPageState();
}

class _TextbookReaderPageState extends State<TextbookReaderPage> {
  Future<void> _addNote() async {
    final title = await askEntryTitle(
      context,
      title: '添加单页',
      hint: '输入单页标题',
    );
    if (!mounted || title == null) return;
    final note = widget.store.createNote(title, parentId: widget.textbook.id);
    setState(() {});
    await Navigator.of(context).push(
      appPageRoute<void>(
        NoteEditorPage(store: widget.store, note: note),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openNote(Entry note) async {
    await Navigator.of(context).push(
      appPageRoute<void>(
        NoteEditorPage(store: widget.store, note: note),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final notes = widget.store.notesUnder(widget.textbook.id);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.textbook.title),
        actions: <Widget>[
          IconButton(
            tooltip: '添加单页',
            onPressed: _addNote,
            icon: const Icon(Icons.note_add_outlined),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              SizedBox(
                height: 120,
                child: EntryCover(
                  entry: widget.textbook,
                  borderRadius: BorderRadius.circular(16),
                  iconSize: 36,
                ),
              ),
              const SizedBox(height: 20),
              SelectableText(
                widget.textbook.content.isEmpty
                    ? '（教材内容为空）'
                    : widget.textbook.content,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.8),
              ),
              const SizedBox(height: 24),
              const Divider(),
              Row(
                children: <Widget>[
                  Text('本教材下的单页笔记', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  Text(
                    '${notes.length} 页',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
              if (notes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    '请添加笔记/笔记本',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                )
              else
                for (final note in notes)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.sticky_note_2_outlined),
                    title: Text(
                      note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('更新于 ${formatEntryTime(note.updatedAt)}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openNote(note),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
