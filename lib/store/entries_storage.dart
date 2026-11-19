import 'package:shared_preferences/shared_preferences.dart';

/// 条目的本地存储。
///
/// 全部数据编码为一个 JSON 字符串：
/// - Android / 桌面：写入 SharedPreferences；
/// - Web：SharedPreferences 底层使用 localStorage。
class EntriesStorage {
  static const String _key = 'study_notebook.entries.v1';

  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  Future<void> write(String data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, data);
  }
}
