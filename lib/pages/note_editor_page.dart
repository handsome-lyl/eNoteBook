import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/entry.dart';
import '../store/app_store.dart';
import '../utils/content_blocks.dart';
import '../widgets/entry_cover.dart';

/// 正文里每个 TextBlock 的辅助结构：controller + focusNode + 稳定 id。
class _TextSlot {
  _TextSlot({
    required this.id,
    required this.controller,
    required this.focusNode,
  });

  final int id;
  final TextEditingController controller;
  final FocusNode focusNode;
}

/// 单页笔记编辑页：标题 + 正文+图片混排 + 归属选择。
/// 图片插入到光标所在位置，插入后光标自动落到图片下方的文字段。
class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key, required this.store, required this.note});

  final AppStore store;
  final Entry note;

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final TextEditingController _titleController;
  late List<ContentBlock> _blocks;
  late List<Uint8List> _images;

  /// 与 _blocks 中的 TextBlock 按顺序一一对应
  final List<_TextSlot> _slots = <_TextSlot>[];

  int _nextSlotId = 0;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _images = cloneImages(widget.note.images);
    _blocks = parseContentBlocks(widget.note.content);
    if (_blocks.whereType<TextBlock>().isEmpty) {
      _blocks.add(TextBlock(''));
    }
    for (final b in _blocks) {
      if (b is TextBlock) {
        _slots.add(_newSlot(b.text));
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final s in _slots) {
      s.controller.dispose();
      s.focusNode.dispose();
    }
    super.dispose();
  }

  _TextSlot _newSlot(String text) {
    return _TextSlot(
      id: _nextSlotId++,
      controller: TextEditingController(text: text),
      focusNode: FocusNode(),
    );
  }

  /// 第 [slotIndex] 个槽位对应 _blocks 中的第几个元素。
  int _blockIndexOfSlot(int slotIndex) {
    var count = 0;
    for (var i = 0; i < _blocks.length; i++) {
      if (_blocks[i] is TextBlock) {
        if (count == slotIndex) return i;
        count++;
      }
    }
    return -1;
  }

  /// _blocks 中第 [blockIndex] 个元素（TextBlock）对应第几个槽位。
  int _slotIndexOfBlock(int blockIndex) {
    var count = 0;
    for (var i = 0; i < blockIndex; i++) {
      if (_blocks[i] is TextBlock) count++;
    }
    return count;
  }

  String get _parentLabel {
    final parentId = widget.note.parentId;
    if (parentId == null) return '未归属';
    return widget.store.byId(parentId)?.title ?? '未归属';
  }

  Future<void> _pickImage() async {
    final file = await FilePicker.pickFile(
      dialogTitle: '选择图片',
      type: FileType.image,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;

    // 记录插入前哪个槽位持有焦点
    final focusedSlot = _slots.indexWhere((s) => s.focusNode.hasFocus);
    final imgIdx = _images.length;
    _images.add(Uint8List.fromList(bytes));

    late _TextSlot afterSlot;

    setState(() {
      if (focusedSlot >= 0) {
        final slot = _slots[focusedSlot];
        final blockIdx = _blockIndexOfSlot(focusedSlot);
        final sel = slot.controller.selection;
        final text = slot.controller.text;
        final cursor = sel.isValid
            ? sel.baseOffset.clamp(0, text.length)
            : text.length;
        final before = text.substring(0, cursor);
        final after = text.substring(cursor);

        // 原槽位保留「光标前」文字
        slot.controller.value = TextEditingValue(
          text: before,
          selection: TextSelection.collapsed(offset: before.length),
        );
        (_blocks[blockIdx] as TextBlock).text = before;

        // 图片 + 光标后文字段
        _blocks.insert(blockIdx + 1, ImageBlock(imgIdx));
        _blocks.insert(blockIdx + 2, TextBlock(after));

        afterSlot = _newSlot(after);
        _slots.insert(focusedSlot + 1, afterSlot);
      } else {
        // 无焦点：插到最后一个文字段之后
        final lastTextBlockIdx = _blocks.lastIndexWhere((b) => b is TextBlock);
        if (lastTextBlockIdx >= 0) {
          _blocks.insert(lastTextBlockIdx + 1, ImageBlock(imgIdx));
          _blocks.insert(lastTextBlockIdx + 2, TextBlock(''));
          afterSlot = _newSlot('');
          _slots.insert(_slotIndexOfBlock(lastTextBlockIdx + 2), afterSlot);
        } else {
          _blocks.add(TextBlock(''));
          _slots.add(_newSlot(''));
          _blocks.add(ImageBlock(imgIdx));
          _blocks.add(TextBlock(''));
          afterSlot = _newSlot('');
          _slots.add(afterSlot);
        }
      }
    });

    // 插图后把光标送到图片下方的文字段，用户可立即继续输入
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      afterSlot.focusNode.requestFocus();
      afterSlot.controller.selection = const TextSelection.collapsed(offset: 0);
    });
  }

  Future<void> _pickParent() async {
    final containers = widget.store.containers;
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: const Text('选择归属'),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop('__none__'),
              child: const Text('不归属'),
            ),
            if (containers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text('暂无可归属的教材或笔记本'),
              ),
            for (final container in containers)
              SimpleDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop(container.id),
                child: Text('${container.kind.label} · ${container.title}'),
              ),
          ],
        );
      },
    );
    if (!mounted || selected == null) return;
    setState(() {
      widget.note.parentId = selected == '__none__' ? null : selected;
    });
  }

  void _removeImage(int blockIndex) {
    if (_blocks[blockIndex] is! ImageBlock) return;
    final imgBlock = _blocks[blockIndex] as ImageBlock;
    setState(() {
      _images.removeAt(imgBlock.imageIndex);
      remapImageIndices(_blocks, imgBlock.imageIndex);
      _blocks.removeAt(blockIndex);

      // 图片两侧的文字段合并，避免留下断裂的空段
      final canMerge = blockIndex > 0 &&
          blockIndex < _blocks.length &&
          _blocks[blockIndex - 1] is TextBlock &&
          _blocks[blockIndex] is TextBlock;
      if (canMerge) {
        final aSlotIdx = _slotIndexOfBlock(blockIndex - 1);
        final aSlot = _slots[aSlotIdx];
        final bSlot = _slots[aSlotIdx + 1];
        final merged = '${aSlot.controller.text}${bSlot.controller.text}';
        aSlot.controller.value = TextEditingValue(
          text: merged,
          selection: TextSelection.collapsed(offset: merged.length),
        );
        (_blocks[blockIndex - 1] as TextBlock).text = merged;
        _blocks.removeAt(blockIndex);

        bSlot.controller.dispose();
        bSlot.focusNode.dispose();
        _slots.removeAt(aSlotIdx + 1);
      }

      if (_blocks.whereType<TextBlock>().isEmpty) {
        _blocks.add(TextBlock(''));
        _slots.add(_newSlot(''));
      }
    });
  }

  void _moveImage(int blockIndex, int delta) {
    if (_blocks[blockIndex] is! ImageBlock) return;
    final newIndex = blockIndex + delta;
    if (newIndex < 0 || newIndex >= _blocks.length) return;
    if (_blocks[newIndex] is ImageBlock) return;
    setState(() {
      final temp = _blocks[blockIndex];
      _blocks[blockIndex] = _blocks[newIndex];
      _blocks[newIndex] = temp;
    });
  }

  void _save() {
    var slotIdx = 0;
    for (final b in _blocks) {
      if (b is TextBlock) {
        b.text = _slots[slotIdx].controller.text;
        slotIdx++;
      }
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('标题不能为空')),
      );
      return;
    }

    widget.note.title = title;
    widget.note.content = serializeContentBlocks(_blocks);
    widget.note.images
      ..clear()
      ..addAll(_images);
    widget.note.updatedAt = DateTime.now();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('单页笔记'),
        actions: <Widget>[
          TextButton(onPressed: _save, child: const Text('保存')),
          const SizedBox(width: 8),
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
                  entry: widget.note,
                  borderRadius: BorderRadius.circular(16),
                  iconSize: 36,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: '标题',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '正文（把光标放到插入点，再点右侧按钮）',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('插入图片'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ..._buildBodyBlocks(),
              const SizedBox(height: 16),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.folder_outlined),
                title: const Text('归属'),
                subtitle: Text(_parentLabel),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickParent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBodyBlocks() {
    final List<Widget> widgets = <Widget>[];
    for (var i = 0; i < _blocks.length; i++) {
      final b = _blocks[i];
      if (b is TextBlock) {
        widgets.add(_buildTextBlock(i));
      } else if (b is ImageBlock) {
        widgets.add(_buildImageBlock(i, b));
      }
    }
    return widgets;
  }

  Widget _buildTextBlock(int blockIndex) {
    final slotIdx = _slotIndexOfBlock(blockIndex);
    if (slotIdx >= _slots.length) return const SizedBox.shrink();
    final slot = _slots[slotIdx];
    return KeyedSubtree(
      key: ValueKey<int>(slot.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: TextField(
          controller: slot.controller,
          focusNode: slot.focusNode,
          minLines: 1,
          maxLines: null,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            isDense: true,
            hintText: '在此输入文字…',
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          ),
        ),
      ),
    );
  }

  Widget _buildImageBlock(int blockIndex, ImageBlock imgBlock) {
    if (imgBlock.imageIndex >= _images.length) {
      return const SizedBox.shrink();
    }
    final isFirst = blockIndex == 0;
    final isLast = blockIndex == _blocks.length - 1;
    return KeyedSubtree(
      key: ValueKey<String>('img-${imgBlock.imageIndex}'),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                _images[imgBlock.imageIndex],
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.arrow_upward),
                  tooltip: '上移',
                  onPressed: isFirst ? null : () => _moveImage(blockIndex, -1),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward),
                  tooltip: '下移',
                  onPressed: isLast ? null : () => _moveImage(blockIndex, 1),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: '删除',
                  onPressed: () => _removeImage(blockIndex),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
