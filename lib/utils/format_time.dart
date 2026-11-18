/// 卡片上的时间：当天只显示时分，当年显示月日
String formatEntryTime(DateTime time) {
  final now = DateTime.now();
  final sameDay =
      time.year == now.year && time.month == now.month && time.day == now.day;
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  if (sameDay) return '$hour:$minute';
  if (time.year == now.year) return '${time.month}月${time.day}日';
  return '${time.year}/${time.month}/${time.day}';
}

/// 历史记录里的完整时间
String formatDateTime(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '${time.year}/${time.month}/${time.day} $hour:$minute';
}
