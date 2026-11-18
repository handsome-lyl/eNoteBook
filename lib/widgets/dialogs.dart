import 'package:flutter/material.dart';

/// 创建笔记本、导入教材、添加单页时统一使用的命名对话框。
///
/// 需求：用户必须为新建的笔记本、导入的教材起一个名字。
/// Controller 的生命周期由对话框自身 State 管理，
/// 避免在退出动画期间被提前 dispose 而崩溃。
Future<String?> askEntryTitle(
  BuildContext context, {
  required String title,
  String? initialValue,
  String hint = '请输入名称',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) =>
        _TitleDialog(title: title, initialValue: initialValue, hint: hint),
  );
}

/// 删除前的二次确认对话框。返回 true 表示用户确认删除。
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final colors = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      );
    },
  );
  return ok ?? false;
}

class _TitleDialog extends StatefulWidget {
  const _TitleDialog({
    required this.title,
    this.initialValue,
    required this.hint,
  });

  final String title;
  final String? initialValue;
  final String hint;

  @override
  State<_TitleDialog> createState() => _TitleDialogState();
}

class _TitleDialogState extends State<_TitleDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = '名称不能为空');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: widget.hint,
          errorText: _error,
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('确定'),
        ),
      ],
    );
  }
}
