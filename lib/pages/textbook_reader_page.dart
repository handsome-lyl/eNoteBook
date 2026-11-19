import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../app_route.dart';
import '../models/entry.dart';
import '../store/app_store.dart';
import '../utils/format_time.dart';
import '../utils/pdf_store.dart';
import '../widgets/dialogs.dart';
import '../widgets/entry_cover.dart';
import 'note_editor_page.dart';

/// 教材阅读页。
///
/// PDF 教材按页原样渲染（文字、插图、版式完整保留）；
/// TXT / MD 教材以文本方式滚动阅读。两种模式都能继续添加单页笔记。
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
  PdfControllerPinch? _pdfController;
  Object? _pdfError;

  @override
  void initState() {
    super.initState();
    final token = widget.textbook.pdfPath;
    if (widget.textbook.hasPdf && token != null) {
      _pdfController = PdfControllerPinch(document: _openDocument(token));
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<PdfDocument> _openDocument(String token) async {
    if (token.startsWith('memory:')) {
      final bytes = await loadPdfBytes(token);
      if (bytes == null) {
        throw StateError('教材文件已失效，请删除该教材后重新导入');
      }
      return PdfDocument.openData(bytes);
    }
    return PdfDocument.openFile(token);
  }

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

  Future<void> _showNotesSheet() async {
    final notes = widget.store.notesUnder(widget.textbook.id);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: notes.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('本教材下还没有单页笔记'),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return ListTile(
                      leading: const Icon(Icons.sticky_note_2_outlined),
                      title: Text(
                        note.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('更新于 ${formatEntryTime(note.updatedAt)}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _openNote(note);
                      },
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildPdfBody(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: PdfViewPinch(
            controller: _pdfController!,
            onDocumentError: (Object error) {
              if (mounted) setState(() => _pdfError = error);
            },
          ),
        ),
        if (_pdfError != null)
          Positioned.fill(
            child: ColoredBox(
              color: colors.surface,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: colors.error,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$_pdfError',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPdf = _pdfController != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.textbook.title),
        actions: <Widget>[
          if (isPdf)
            IconButton(
              tooltip: '单页笔记',
              onPressed: _showNotesSheet,
              icon: const Icon(Icons.sticky_note_2_outlined),
            ),
          IconButton(
            tooltip: '添加单页',
            onPressed: _addNote,
            icon: const Icon(Icons.note_add_outlined),
          ),
        ],
      ),
      body: isPdf ? _buildPdfBody(context) : _buildTextBody(context),
    );
  }

  Widget _buildTextBody(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final notes = widget.store.notesUnder(widget.textbook.id);
    return Center(
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
    );
  }
}
