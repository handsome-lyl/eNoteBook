import 'package:flutter/material.dart';

import '../app_route.dart';
import '../models/entry.dart';
import '../store/app_store.dart';
import '../utils/format_time.dart';
import '../widgets/dialogs.dart';
import '../widgets/entry_cover.dart';
import 'note_editor_page.dart';

/// 笔记本详情页：列出笔记本下的单页笔记，并可继续添加。
class NotebookDetailPage extends StatefulWidget {
  const NotebookDetailPage({
    super.key,
    required this.store,
    required this.notebook,
  });

  final AppStore store;
  final Entry notebook;

  @override
  State<NotebookDetailPage> createState() => _NotebookDetailPageState();
}

class _NotebookDetailPageState extends State<NotebookDetailPage> {
  Future<void> _addNote() async {
    final title = await askEntryTitle(
      context,
      title: '添加单页',
      hint: '输入单页标题',
    );
    if (!mounted || title == null) return;
    final note = widget.store.createNote(title, parentId: widget.notebook.id);
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
    final notes = widget.store.notesUnder(widget.notebook.id);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.notebook.title),
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
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SizedBox(
                  height: 140,
                  child: EntryCover(
                    entry: widget.notebook,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: <Widget>[
                    Text('单页笔记', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    Text(
                      '${notes.length} 页',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: notes.isEmpty
                    ? Center(
                        child: Text(
                          '请添加笔记/笔记本',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                        itemCount: notes.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final note = notes[index];
                          return ListTile(
                            leading: const Icon(Icons.sticky_note_2_outlined),
                            title: Text(
                              note.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle:
                                Text('更新于 ${formatEntryTime(note.updatedAt)}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openNote(note),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
