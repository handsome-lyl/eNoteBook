import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app_route.dart';
import '../models/entry.dart';
import '../store/app_store.dart';
import '../utils/format_time.dart';
import '../utils/pdf_extract.dart';
import '../widgets/add_sheet.dart';
import '../widgets/dialogs.dart';
import '../widgets/entry_card.dart';
import 'note_editor_page.dart';
import 'notebook_detail_page.dart';
import 'textbook_reader_page.dart';

/// 主界面：顶部栏 + 内容卡片 + 底部加号（宽屏时改为左侧导航栏）。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final AppStore _store = AppStore();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// 卡片入场使用的交织动画控制器（教材 9.5：交织动画）
  late final AnimationController _introController;

  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _introController.dispose();
    super.dispose();
  }

  void _refreshList() {
    setState(() {});
    _introController.forward(from: 0);
  }

  void _resetList() {
    if (_keyword.isNotEmpty) {
      _searchController.clear();
      setState(() => _keyword = '');
    }
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    _introController.forward(from: 0);
  }

  Future<void> _showAddMenu() async {
    final action = await showAddSheet(context);
    if (!mounted || action == null) return;
    switch (action) {
      case AddAction.textbook:
        await _addTextbook();
      case AddAction.note:
        await _addNote();
      case AddAction.notebook:
        await _addNotebook();
    }
  }

  Future<void> _addTextbook() async {
    final file = await FilePicker.pickFile(
      dialogTitle: '选择教材文件',
      type: FileType.custom,
      allowedExtensions: const <String>['txt', 'md', 'pdf'],
    );
    if (file == null) return;
    final ext = file.name.toLowerCase().split('.').last;

    String content;
    try {
      final bytes = await file.readAsBytes();
      if (ext == 'pdf') {
        content = extractPdfText(bytes);
        if (content.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('未能从 PDF 中提取文本（可能使用了内嵌字体）'),
            ),
          );
          return;
        }
      } else {
        content = utf8.decode(bytes, allowMalformed: true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('读取文件失败: $e')),
      );
      return;
    }

    if (!mounted) return;
    final title = await askEntryTitle(
      context,
      title: '为教材命名',
      initialValue: _stripExtension(file.name),
      hint: '输入教材名称',
    );
    if (!mounted || title == null) return;
    _store.createTextbook(title, content);
    _refreshList();
  }

  Future<void> _addNote() async {
    final title = await askEntryTitle(
      context,
      title: '添加单页',
      hint: '输入单页标题',
    );
    if (!mounted || title == null) return;
    final note = _store.createNote(title);
    _refreshList();
    await _openEntry(note);
  }

  Future<void> _addNotebook() async {
    final title = await askEntryTitle(
      context,
      title: '新建笔记本',
      hint: '输入笔记本名称',
    );
    if (!mounted || title == null) return;
    _store.createNotebook(title);
    _refreshList();
  }

  String _stripExtension(String name) {
    final index = name.lastIndexOf('.');
    return index > 0 ? name.substring(0, index) : name;
  }

  Future<void> _openEntry(Entry entry) async {
    final Widget page = switch (entry.kind) {
      EntryKind.textbook =>
        TextbookReaderPage(store: _store, textbook: entry),
      EntryKind.notebook =>
        NotebookDetailPage(store: _store, notebook: entry),
      EntryKind.note => NoteEditorPage(store: _store, note: entry),
    };
    await Navigator.of(context).push(appPageRoute<void>(page));
    if (mounted) setState(() {});
  }

  Future<void> _showAuthDialog() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _AuthDialog(),
    );
    if (!mounted || name == null) return;
    setState(() => _store.currentUser = name);
  }

  Future<void> _showHistory() async {
    final notes = _store.noteHistory;
    final selected = await showDialog<Entry>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('历史记录'),
          content: SizedBox(
            width: 380,
            height: 360,
            child: notes.isEmpty
                ? const Center(child: Text('暂无单页笔记记录'))
                : ListView.separated(
                    itemCount: notes.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.sticky_note_2_outlined),
                        title: Text(
                          note.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text('创建于 ${formatDateTime(note.createdAt)}'),
                        onTap: () => Navigator.of(dialogContext).pop(note),
                      );
                    },
                  ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
    if (!mounted || selected == null) return;
    await _openEntry(selected);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Material 3 窗口尺寸类：compact(<600) 用底栏，medium 及以上用左侧导航栏
        final wide = constraints.maxWidth >= 600;
        if (wide) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: <Widget>[
                  _buildNavigationRail(),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        _buildTopBar(wide: true),
                        Expanded(child: _buildContent()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: <Widget>[
                _buildTopBar(wide: false),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomBar(),
        );
      },
    );
  }

  Widget _buildNavigationRail() {
    return NavigationRail(
      selectedIndex: 0,
      labelType: NavigationRailLabelType.all,
      onDestinationSelected: (_) => _resetList(),
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: FloatingActionButton(
          onPressed: _showAddMenu,
          tooltip: '添加',
          child: const Icon(Icons.add),
        ),
      ),
      destinations: const <NavigationRailDestination>[
        NavigationRailDestination(
          icon: Icon(Icons.view_list_outlined),
          selectedIcon: Icon(Icons.view_list),
          label: Text('列表'),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return BottomAppBar(
      height: 72,
      padding: EdgeInsets.zero,
      child: Center(
        child: FloatingActionButton(
          onPressed: _showAddMenu,
          tooltip: '添加',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildTopBar({required bool wide}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = _store.currentUser;
    final searchField = TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onChanged: (value) => setState(() => _keyword = value.trim()),
      decoration: InputDecoration(
        hintText: wide ? '搜索笔记本、教材' : '搜索',
        prefixIcon: const Icon(Icons.search),
        isDense: true,
        filled: true,
        fillColor: colors.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        suffixIcon: _keyword.isEmpty
            ? null
            : IconButton(
                tooltip: '清除',
                icon: const Icon(Icons.close),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _keyword = '');
                },
              ),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 24 : 12, 12, wide ? 24 : 8, 4),
      child: Row(
        children: <Widget>[
          if (wide)
            SizedBox(width: 360, child: searchField)
          else
            Expanded(child: searchField),
          const SizedBox(width: 8),
          IconButton(
            tooltip: '更多',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('更多功能后续添加')),
              );
            },
            icon: const Icon(Icons.more_horiz),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: '账户',
            offset: const Offset(0, 44),
            onSelected: (value) async {
              switch (value) {
                case 'auth':
                  await _showAuthDialog();
                case 'logout':
                  setState(() => _store.currentUser = null);
                case 'history':
                  await _showHistory();
              }
            },
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              if (user == null)
                const PopupMenuItem<String>(
                  value: 'auth',
                  child: Text('登录/注册'),
                )
              else
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Text('退出登录'),
                ),
              const PopupMenuItem<String>(
                value: 'history',
                child: Text('历史记录'),
              ),
            ],
            child: CircleAvatar(
              radius: 18,
              backgroundColor: colors.primaryContainer,
              child: user == null
                  ? Icon(Icons.person_outline,
                      size: 20, color: colors.onPrimaryContainer)
                  : Text(
                      user.characters.first.toUpperCase(),
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: colors.onPrimaryContainer),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final entries = _store.search(_keyword);
    final searching = _keyword.isNotEmpty;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: entries.isEmpty
          ? Container(
              key: const ValueKey<String>('empty'),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.edit_note, size: 64, color: colors.outline),
                  const SizedBox(height: 12),
                  Text(
                    searching ? '没有找到匹配的笔记本或教材' : '请添加笔记/笔记本',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            )
          : _buildGrid(entries),
    );
  }

  Widget _buildGrid(List<Entry> entries) {
    return LayoutBuilder(
      key: const ValueKey<String>('grid'),
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns =
            width < 600 ? 2 : width < 1024 ? 3 : width < 1440 ? 4 : 5;
        final padding = width < 600 ? 12.0 : 24.0;
        const spacing = 16.0;
        final cardWidth =
            (width - padding * 2 - spacing * (columns - 1)) / columns;
        final mainAxisExtent = cardWidth * 0.62 + 96;

        return GridView.builder(
          controller: _scrollController,
          padding: EdgeInsets.all(padding),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            mainAxisExtent: mainAxisExtent,
          ),
          itemCount: entries.length,
          itemBuilder: (context, index) =>
              _buildAnimatedCard(entries[index], index),
        );
      },
    );
  }

  /// 每张卡片使用不同的 Interval，形成依次入场的交织动画
  Widget _buildAnimatedCard(Entry entry, int index) {
    final start = (index * 0.07).clamp(0.0, 0.5);
    final animation = CurvedAnimation(
      parent: _introController,
      curve: Interval(
        start,
        (start + 0.5).clamp(0.0, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
        child: EntryCard(
          entry: entry,
          onTap: () => _openEntry(entry),
        ),
      ),
    );
  }
}

/// 登录/注册对话框。
///
/// 本地简单校验：用户名非空、密码至少 6 位。
/// 成功后返回用户名字符串，用于头像首字母展示。
/// Controller 的生命周期由对话框自身 State 管理，
/// 避免在退出动画期间被提前 dispose 而崩溃。
class _AuthDialog extends StatefulWidget {
  const _AuthDialog();

  @override
  State<_AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<_AuthDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _pwdController;
  String? _nameError;
  String? _pwdError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _pwdController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pwdController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final pwd = _pwdController.text;
    setState(() {
      _nameError = name.isEmpty ? '请输入用户名' : null;
      _pwdError = pwd.length < 6 ? '密码至少 6 位' : null;
    });
    if (_nameError == null && _pwdError == null) {
      Navigator.of(context).pop(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('登录 / 注册'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _nameController,
            autofocus: true,
            maxLength: 20,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: '用户名',
              errorText: _nameError,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _pwdController,
            obscureText: true,
            maxLength: 20,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: '密码',
              errorText: _pwdError,
            ),
          ),
        ],
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
