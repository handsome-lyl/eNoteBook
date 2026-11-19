import 'dart:async';

import '../models/entry.dart';
import 'entries_storage.dart';
import 'store_codec.dart';

/// 数据仓库。
///
/// 传入 [EntriesStorage] 时，每次改动都会把全部条目写入本地存储；
/// 不传时（单元测试）只做内存存储。
class AppStore {
  AppStore([this._storage]) {
    _seed();
  }

  AppStore._(this._storage);

  /// 从本地存储恢复数据；没有存档或存档损坏时写入示例数据。
  static Future<AppStore> open() async {
    final storage = EntriesStorage();
    final store = AppStore._(storage);
    try {
      final raw = await storage.read();
      if (raw != null && raw.isNotEmpty) {
        store._entries.addAll(decodeEntries(raw));
      }
    } catch (_) {
      store._entries.clear();
    }
    if (store._entries.isEmpty) {
      store._seed();
      await store.persist();
    }
    return store;
  }

  final EntriesStorage? _storage;

  /// 串行化的保存任务，保证后一次快照不会先于前一次写入
  Future<bool>? _pendingSave;

  final List<Entry> _entries = <Entry>[];

  /// 当前登录用户名，null 表示未登录
  String? currentUser;

  int _seq = 0;

  String _nextId() =>
      'e${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  /// 主页展示的全部条目（教材、笔记本、单页笔记混排）
  List<Entry> sortedEntries() {
    final list = List<Entry>.of(_entries);
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  /// 关键词搜索：按需求只匹配笔记本与教材的名称
  List<Entry> search(String keyword) {
    final k = keyword.trim().toLowerCase();
    if (k.isEmpty) return sortedEntries();
    final list = _entries
        .where((e) => e.isContainer && e.title.toLowerCase().contains(k))
        .toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  List<Entry> get notes =>
      _entries.where((e) => e.kind == EntryKind.note).toList();

  /// 历史记录：所有单页笔记的新建记录，按创建时间倒序
  List<Entry> get noteHistory {
    final list = notes..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// 某个笔记本 / 教材下附属的单页笔记
  List<Entry> notesUnder(String parentId) {
    final list = _entries
        .where((e) => e.isNote && e.parentId == parentId)
        .toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  /// 可作为归属的容器：笔记本 + 教材
  List<Entry> get containers =>
      _entries.where((e) => e.isContainer).toList();

  Entry? byId(String id) {
    for (final entry in _entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  Entry createTextbook(String title, String content) {
    final entry = Entry(
      id: _nextId(),
      kind: EntryKind.textbook,
      title: title,
      content: content,
    );
    _entries.add(entry);
    unawaited(persist());
    return entry;
  }

  Entry createNotebook(String title) {
    final entry = Entry(
      id: _nextId(),
      kind: EntryKind.notebook,
      title: title,
    );
    _entries.add(entry);
    unawaited(persist());
    return entry;
  }

  Entry createNote(String title, {String? parentId, String? content}) {
    final entry = Entry(
      id: _nextId(),
      kind: EntryKind.note,
      title: title,
      content: content ?? '',
      parentId: parentId,
    );
    _entries.add(entry);
    unawaited(persist());
    return entry;
  }

  void touch(Entry entry) {
    entry.updatedAt = DateTime.now();
    unawaited(persist());
  }

  /// 把当前全部条目写入本地存储，返回是否成功。
  ///
  /// 多次调用会串行执行，最后写入的是最新快照。
  Future<bool> persist() {
    final previous = _pendingSave ?? Future<bool>.value(true);
    final next = previous.then((_) => _writeSnapshot());
    _pendingSave = next;
    return next;
  }

  Future<bool> _writeSnapshot() async {
    final storage = _storage;
    if (storage == null) return true;
    try {
      await storage.write(encodeEntries(_entries));
      return true;
    } catch (_) {
      // Web 端 localStorage 超出配额等情况
      return false;
    }
  }

  /// 删除条目。若删除的是笔记本或教材，其下的单页笔记一并删除，
  /// 避免留下无法访问的孤儿笔记。
  void deleteEntry(Entry entry) {
    _entries.removeWhere((e) => e.id == entry.id);
    if (entry.isContainer) {
      _entries.removeWhere((e) => e.parentId == entry.id);
    }
    unawaited(persist());
  }

  /// 初始示例数据，便于直接看到动画效果
  void _seed() {
    createTextbook(
      '移动软件开发 · 第九章动画',
      '第九章 Flutter 动画\n\n'
      '9.1 动画基本原理\n'
      '在任何 UI 框架中，动画的实现原理都是相同的：在一段时间内快速多次改变 UI 外观，'
      '利用人眼视觉暂留形成连续动画。\n\n'
      '9.2 动画基本结构\n'
      'AnimationController 每帧生成 0.0 到 1.0 的数值，Tween 将其映射为实际数值，'
      'Curve 决定变化节奏，AnimatedBuilder 负责把数值渲染成界面。\n\n'
      '9.3 自定义路由切换动画\n'
      'PageRouteBuilder 可以在路由切换时自定义过渡动画。\n\n'
      '9.4 Hero 动画\n'
      'Hero 让共享组件在路由之间飞行，前后路由的 tag 必须相同。\n\n'
      '9.5 交织动画\n'
      '一个 AnimationController 驱动多个 Tween，通过 Interval 划分时间段。\n\n'
      '9.7 动画过渡组件\n'
      'AnimatedContainer、AnimatedOpacity 等隐式动画组件会在属性变化时自动过渡。',
    );
    createNotebook('课程笔记');
    createNote(
      '动画三要素',
      parentId: _entries.last.id,
      content: '动画三要素：\n\n'
          '1. AnimationController —— 控制器，每帧生成 0.0 到 1.0 的线性数值；\n'
          '2. Tween —— 补间，把控制器数值映射为实际需要的值（如颜色、尺寸）；\n'
          '3. Curve —— 曲线，决定动画的变化节奏（如 easeIn、easeOut）。\n\n'
          '通过 addListener 监听数值变化并调用 setState 刷新界面，'
          '配合 AnimatedBuilder 可以简化监听与重建。',
    );
  }
}
