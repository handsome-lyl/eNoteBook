library;

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

/// 纯 Dart PDF 文本提取。
///
/// 支持 FlateDecode 压缩流、PDF 1.5+ 对象流（ObjStm）、
/// Type0/CID 字体（通过 ToUnicode CMap 还原中文）。
/// 解析失败时回落到只在未压缩内容流里扫描 `BT...ET` 的旧逻辑。
///
/// 原生平台放到独立 isolate 中执行，Web 端逐页让出事件循环并回报进度，
/// 避免大文件解析时界面无响应。
Future<String> extractPdfText(
  Uint8List bytes, {
  void Function(int done, int total)? onProgress,
}) async {
  if (!kIsWeb) {
    try {
      final text = await compute(_extractTextSync, bytes);
      if (text.trim().isNotEmpty) return text;
    } catch (_) {
      // 继续尝试旧方式
    }
    return _legacyExtract(bytes).trim();
  }
  try {
    final text = await _PdfDocument(bytes).extractTextAsync(onProgress);
    if (text.trim().isNotEmpty) return text;
  } catch (_) {
    // 继续尝试旧方式
  }
  return _legacyExtract(bytes).trim();
}

String _extractTextSync(Uint8List bytes) {
  try {
    final text = _PdfDocument(bytes).extractText().trim();
    if (text.isNotEmpty) return text;
  } catch (_) {
    // 继续尝试旧方式
  }
  return _legacyExtract(bytes);
}


/// 无法解析对象结构时的兜底：直接扫描未压缩的文本块。
String _legacyExtract(Uint8List bytes) {
  final raw = latin1.decode(bytes);
  final buffer = StringBuffer();
  final btEt = RegExp(r'BT(.*?)ET', multiLine: true, dotAll: true);
  final textRe = RegExp(r'\((?:\\.|[^\\)])*\)\s*Tj');
  final arrayRe = RegExp(r'\[(.*?)\]\s*TJ', dotAll: true);
  for (final block in btEt.allMatches(raw)) {
    final content = block.group(1)!;
    for (final m in textRe.allMatches(content)) {
      buffer.write(_legacyUnescape(m.group(0)!.replaceAll(RegExp(r'\)\s*Tj$'), '').substring(1)));
    }
    for (final m in arrayRe.allMatches(content)) {
      for (final s in RegExp(r'\((?:\\.|[^\\)])*\)').allMatches(m.group(1)!)) {
        buffer.write(_legacyUnescape(s.group(0)!.substring(1, s.group(0)!.length - 1)));
      }
    }
  }
  return buffer.toString().trim();
}

String _legacyUnescape(String s) {
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (c != 0x5C || i + 1 >= s.length) {
      out.writeCharCode(c);
      continue;
    }
    final n = s.codeUnitAt(++i);
    switch (n) {
      case 0x6E:
        out.write('\n');
      case 0x72:
        out.write('\r');
      case 0x74:
        out.write('\t');
      case 0x62:
        out.writeCharCode(8);
      case 0x66:
        out.writeCharCode(12);
      default:
        if (n >= 0x30 && n <= 0x37) {
          var oct = n - 0x30;
          var count = 1;
          while (count < 3 && i + 1 < s.length) {
            final d = s.codeUnitAt(i + 1);
            if (d < 0x30 || d > 0x37) break;
            oct = oct * 8 + (d - 0x30);
            i++;
            count++;
          }
          out.writeCharCode(oct & 0xFF);
        } else {
          out.writeCharCode(n);
        }
    }
  }
  return out.toString();
}

class _PdfObj {
  _PdfObj(this.dict, this.stream);

  /// 字典部分（已去掉 stream 数据）
  final String dict;

  /// 未解压的流数据
  final Uint8List? stream;
}

class _FontInfo {
  const _FontInfo(this.cmap, {this.twoByte = false});

  static const _FontInfo simple = _FontInfo(null);

  final Map<int, String>? cmap;
  final bool twoByte;
}

class _PdfString {
  const _PdfString(this.raw);
  final String raw;
}

class _PdfName {
  const _PdfName(this.name);
  final String name;
}

class _PdfArray {
  const _PdfArray(this.items);
  final List<Object> items;
}

class _TextSink {
  final StringBuffer _buffer = StringBuffer();
  String _last = '';

  bool get isEmpty => _buffer.isEmpty;

  void write(String text) {
    if (text.isEmpty) return;
    _buffer.write(text);
    _last = text;
  }

  void newline() {
    if (_buffer.isEmpty) return;
    if (!_last.endsWith('\n')) {
      _buffer.write('\n');
      _last = '\n';
    }
  }

  @override
  String toString() => _buffer.toString();
}

class _PdfDocument {
  _PdfDocument(Uint8List bytes) : _raw = latin1.decode(bytes) {
    _parseObjects(bytes);
  }

  final String _raw;
  final Map<int, _PdfObj> _objects = <int, _PdfObj>{};
  final Map<int, Map<int, String>> _cmapCache = <int, Map<int, String>>{};

  // ---------------------------------------------------------------- 解析结构

  void _parseObjects(Uint8List bytes) {
    final objRe = RegExp(r'(\d+)\s+(\d+)\s+obj\b');
    for (final m in objRe.allMatches(_raw)) {
      final start = m.end;
      final endIdx = _raw.indexOf('endobj', start);
      if (endIdx < 0) continue;
      var body = _raw.substring(start, endIdx);
      Uint8List? stream;

      final sMatch = RegExp(r'(?<!end)stream\r?\n').firstMatch(body);
      if (sMatch != null) {
        final dataStart = start + sMatch.end;
        final eIdx = _raw.indexOf('endstream', dataStart);
        if (eIdx > dataStart && eIdx <= endIdx) {
          var dataEnd = eIdx;
          if (dataEnd > dataStart && _raw[dataEnd - 1] == '\n') dataEnd--;
          if (dataEnd > dataStart && _raw[dataEnd - 1] == '\r') dataEnd--;
          stream = Uint8List.sublistView(bytes, dataStart, dataEnd);
          body = body.substring(0, sMatch.start);
        }
      }
      _objects[int.parse(m.group(1)!)] = _PdfObj(body, stream);
    }
  }

  void _expandObjectStreams() {
    final ids = _objects.entries
        .where((e) => RegExp(r'/Type\s*/ObjStm').hasMatch(e.value.dict))
        .map((e) => e.key)
        .toList();
    for (final id in ids) {
      _expandOneObjStm(id);
    }
  }

  void _expandOneObjStm(int id) {
    final obj = _objects[id];
    if (obj == null) return;
    final decoded = _decodeStream(obj);
    if (decoded == null) return;
    final text = latin1.decode(decoded);
    final nMatch = RegExp(r'/N\s+(\d+)').firstMatch(obj.dict);
    final fMatch = RegExp(r'/First\s+(\d+)').firstMatch(obj.dict);
    if (nMatch == null || fMatch == null) return;
    final n = int.parse(nMatch.group(1)!);
    final first = int.parse(fMatch.group(1)!);
    if (first > text.length) return;
    final header = text.substring(0, first).trim().split(RegExp(r'\s+'));
    final nums = <int>[];
    for (final h in header) {
      final v = int.tryParse(h);
      if (v != null) nums.add(v);
    }
    for (var i = 0; i < n && 2 * i + 1 < nums.length; i++) {
      final objNum = nums[2 * i];
      final startPos = first + nums[2 * i + 1];
      final endPos = (i + 1 < n && 2 * (i + 1) + 1 < nums.length)
          ? first + nums[2 * (i + 1) + 1]
          : text.length;
      if (startPos >= text.length || startPos >= endPos) continue;
      final body = text.substring(startPos, endPos.clamp(0, text.length));
      _objects.putIfAbsent(objNum, () => _PdfObj(body.trim(), null));
    }
  }

  Uint8List? _decodeStream(_PdfObj obj) {
    final data = obj.stream;
    if (data == null || data.isEmpty) return null;
    final filterMatch = RegExp(r'/Filter\s*(\[[^\]]*\]|/\w+)').firstMatch(obj.dict);
    final filter = filterMatch?.group(1) ?? '';
    if (filter.isEmpty || filter.contains('FlateDecode')) {
      try {
        return const ZLibDecoder().decodeBytes(data);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------- 页面遍历

  String extractText() {
    _expandObjectStreams();
    final pages = _pageIds();
    final sink = _TextSink();
    for (final id in pages) {
      final text = _pageText(id).trim();
      if (text.isEmpty) continue;
      if (!sink.isEmpty) sink.write('\n\n');
      sink.write(text);
    }
    return sink.toString();
  }

  /// Web 端使用：每处理完一项就让出事件循环，避免长时间阻塞 UI。
  Future<String> extractTextAsync(
    void Function(int done, int total)? onProgress,
  ) async {
    final ids = _objects.entries
        .where((e) => RegExp(r'/Type\s*/ObjStm').hasMatch(e.value.dict))
        .map((e) => e.key)
        .toList();
    for (final id in ids) {
      _expandOneObjStm(id);
      await Future<void>.delayed(Duration.zero);
    }

    final pages = _pageIds();
    final sink = _TextSink();
    for (var i = 0; i < pages.length; i++) {
      final text = _pageText(pages[i]).trim();
      if (text.isNotEmpty) {
        if (!sink.isEmpty) sink.write('\n\n');
        sink.write(text);
      }
      onProgress?.call(i + 1, pages.length);
      await Future<void>.delayed(Duration.zero);
    }
    return sink.toString();
  }

  List<int> _pageIds() {
    final ordered = <int>[];
    final roots = _objects.entries
        .where((e) =>
            RegExp(r'/Type\s*/Pages').hasMatch(e.value.dict) &&
            !RegExp(r'/Parent\s').hasMatch(e.value.dict))
        .toList();
    for (final root in roots) {
      _collectPages(root.value.dict, ordered);
    }
    if (ordered.isNotEmpty) return ordered;
    return _objects.entries
        .where((e) => RegExp(r'/Type\s*/Page[^s]').hasMatch(e.value.dict))
        .map((e) => e.key)
        .toList()
      ..sort();
  }

  void _collectPages(String dict, List<int> out) {
    final kids = RegExp(r'/Kids\s*\[([^\]]*)\]').firstMatch(dict);
    if (kids == null) return;
    for (final m in RegExp(r'(\d+)\s+\d+\s+R').allMatches(kids.group(1)!)) {
      final id = int.parse(m.group(1)!);
      final obj = _objects[id];
      if (obj == null) continue;
      if (RegExp(r'/Type\s*/Pages').hasMatch(obj.dict)) {
        _collectPages(obj.dict, out);
      } else {
        out.add(id);
        final count = RegExp(r'/Count\s+(\d+)').firstMatch(obj.dict);
        if (count != null && int.parse(count.group(1)!) == 0) {
          // 空页面，忽略
        }
      }
    }
  }

  String _pageText(int pageId) {
    final page = _objects[pageId];
    if (page == null) return '';
    final fonts = _fontsOf(pageId);
    final sink = _TextSink();
    for (final id in _contentIds(page.dict)) {
      final obj = _objects[id];
      if (obj == null) continue;
      final data = _decodeStream(obj);
      if (data == null) continue;
      _decodeContent(data, fonts, sink);
      sink.newline();
    }
    return sink.toString();
  }

  List<int> _contentIds(String pageDict) {
    final m = RegExp(r'/Contents\s*(\[[^\]]*\]|\d+\s+\d+\s+R)').firstMatch(pageDict);
    if (m == null) return const <int>[];
    return RegExp(r'(\d+)\s+\d+\s+R')
        .allMatches(m.group(1)!)
        .map((e) => int.parse(e.group(1)!))
        .toList();
  }

  // ---------------------------------------------------------------- 字体映射

  Map<String, _FontInfo> _fontsOf(int pageId) {
    final resources = _resourcesOf(pageId);
    if (resources == null) return const <String, _FontInfo>{};
    final fontDict = _dictValue(resources, 'Font');
    if (fontDict == null) return const <String, _FontInfo>{};

    final result = <String, _FontInfo>{};
    for (final m in RegExp(r'/([^\s/<>\[\](){}]+)\s+(\d+)\s+\d+\s+R').allMatches(fontDict)) {
      final name = m.group(1)!;
      final id = int.parse(m.group(2)!);
      final obj = _objects[id];
      if (obj == null) continue;
      final twoByte = RegExp(r'/Type0|/Subtype\s*/Type0').hasMatch(obj.dict);
      Map<int, String>? cmap;
      final toUnicode = RegExp(r'/ToUnicode\s+(\d+)\s+\d+\s+R').firstMatch(obj.dict);
      if (toUnicode != null) {
        cmap = _cmapFor(int.parse(toUnicode.group(1)!));
      }
      result[name] = _FontInfo(cmap, twoByte: twoByte);
    }
    return result;
  }

  String? _resourcesOf(int pageId) {
    var id = pageId;
    for (var guard = 0; guard < 20; guard++) {
      final obj = _objects[id];
      if (obj == null) return null;
      final resources = _dictValue(obj.dict, 'Resources');
      if (resources != null) return resources;
      final parent = RegExp(r'/Parent\s+(\d+)\s+\d+\s+R').firstMatch(obj.dict);
      if (parent == null) return null;
      id = int.parse(parent.group(1)!);
    }
    return null;
  }

  /// 取字典 [dict] 中 [key] 对应的值：内联字典返回其内容，引用则解析到对象字典。
  String? _dictValue(String dict, String key) {
    final m = RegExp('/$key\\b\\s*').firstMatch(dict);
    if (m == null) return null;
    final i = m.end;
    if (i >= dict.length) return null;
    if (dict.startsWith('<<', i)) return _balancedDict(dict, i);
    final ref = RegExp(r'(\d+)\s+\d+\s+R').matchAsPrefix(dict, i);
    if (ref != null) return _objects[int.parse(ref.group(1)!)]?.dict;
    return null;
  }

  String _balancedDict(String s, int start) {
    var i = start;
    var depth = 0;
    final buf = StringBuffer();
    while (i < s.length) {
      if (s.startsWith('<<', i)) {
        depth++;
        if (depth > 1) buf.write('<<');
        i += 2;
        continue;
      }
      if (s.startsWith('>>', i)) {
        depth--;
        i += 2;
        if (depth == 0) break;
        buf.write('>>');
        continue;
      }
      buf.write(s[i]);
      i++;
    }
    return buf.toString();
  }

  Map<int, String>? _cmapFor(int id) {
    if (_cmapCache.containsKey(id)) return _cmapCache[id];
    final obj = _objects[id];
    final data = obj == null ? null : _decodeStream(obj);
    if (data == null) return null;
    final text = latin1.decode(data);
    final map = <int, String>{};

    for (final block in RegExp(r'beginbfchar(.*?)endbfchar', dotAll: true).allMatches(text)) {
      for (final p in RegExp(r'<([0-9a-fA-F]+)>\s*<([0-9a-fA-F]*)>').allMatches(block.group(1)!)) {
        map[int.parse(p.group(1)!, radix: 16)] = _hexToUnicode(p.group(2)!);
      }
    }
    for (final block in RegExp(r'beginbfrange(.*?)endbfrange', dotAll: true).allMatches(text)) {
      final body = block.group(1)!;
      for (final p
          in RegExp(r'<([0-9a-fA-F]+)>\s*<([0-9a-fA-F]+)>\s*\[(.*?)\]', dotAll: true).allMatches(body)) {
        var code = int.parse(p.group(1)!, radix: 16);
        for (final d in RegExp(r'<([0-9a-fA-F]*)>').allMatches(p.group(3)!)) {
          map[code++] = _hexToUnicode(d.group(1)!);
        }
      }
      for (final p
          in RegExp(r'<([0-9a-fA-F]+)>\s*<([0-9a-fA-F]+)>\s*<([0-9a-fA-F]*)>').allMatches(body)) {
        final lo = int.parse(p.group(1)!, radix: 16);
        final hi = int.parse(p.group(2)!, radix: 16);
        final dst = _hexToUnicode(p.group(3)!);
        for (var code = lo; code <= hi && code - lo < 512; code++) {
          if (dst.isEmpty) break;
          map[code] = String.fromCharCode(dst.codeUnitAt(0) + (code - lo));
        }
      }
    }
    _cmapCache[id] = map;
    return map;
  }

  String _hexToUnicode(String hex) {
    if (hex.isEmpty) return '';
    if (hex.length.isOdd) hex = '0$hex';
    final codes = <int>[];
    if (hex.length % 4 == 0) {
      for (var i = 0; i < hex.length; i += 4) {
        codes.add(int.parse(hex.substring(i, i + 4), radix: 16));
      }
    } else {
      for (var i = 0; i < hex.length; i += 2) {
        codes.add(int.parse(hex.substring(i, i + 2), radix: 16));
      }
    }
    return String.fromCharCodes(codes);
  }

  // ---------------------------------------------------------------- 内容解码

  void _decodeContent(Uint8List data, Map<String, _FontInfo> fonts, _TextSink sink) {
    final s = latin1.decode(data);
    final operands = <Object>[];
    var font = _FontInfo.simple;
    double? lastY;
    var i = 0;

    while (i < s.length) {
      final c = s.codeUnitAt(i);
      if (_isWhitespace(c)) {
        i++;
        continue;
      }
      if (c == 0x25) {
        while (i < s.length && s.codeUnitAt(i) != 0x0A) {
          i++;
        }
        continue;
      }
      if (c == 0x28) {
        final r = _readLiteral(s, i);
        operands.add(_PdfString(r.text));
        i = r.next;
        continue;
      }
      if (c == 0x3C) {
        if (i + 1 < s.length && s.codeUnitAt(i + 1) == 0x3C) {
          i = _skipDict(s, i);
          continue;
        }
        final end = s.indexOf('>', i + 1);
        if (end < 0) break;
        operands.add(_PdfString(_hexToBytes(s.substring(i + 1, end))));
        i = end + 1;
        continue;
      }
      if (c == 0x5B) {
        final arr = <Object>[];
        i++;
        while (i < s.length && s.codeUnitAt(i) != 0x5D) {
          final ch = s.codeUnitAt(i);
          if (_isWhitespace(ch)) {
            i++;
            continue;
          }
          if (ch == 0x28) {
            final r = _readLiteral(s, i);
            arr.add(_PdfString(r.text));
            i = r.next;
            continue;
          }
          if (ch == 0x3C) {
            final end = s.indexOf('>', i + 1);
            if (end < 0) {
              i = s.length;
              break;
            }
            arr.add(_PdfString(_hexToBytes(s.substring(i + 1, end))));
            i = end + 1;
            continue;
          }
          final start = i;
          while (i < s.length && !_isDelimiter(s.codeUnitAt(i))) {
            i++;
          }
          final token = s.substring(start, i);
          arr.add(num.tryParse(token) ?? _PdfName(token));
        }
        i++;
        operands.add(_PdfArray(arr));
        continue;
      }
      if (c == 0x2F) {
        final start = i + 1;
        i = start;
        while (i < s.length && !_isDelimiter(s.codeUnitAt(i))) {
          i++;
        }
        operands.add(_PdfName(s.substring(start, i)));
        continue;
      }
      if (c == 0x5D || c == 0x3E || c == 0x7B || c == 0x7D || c == 0x29) {
        i++;
        continue;
      }

      final start = i;
      while (i < s.length && !_isDelimiter(s.codeUnitAt(i))) {
        i++;
      }
      final token = s.substring(start, i);
      final value = num.tryParse(token);
      if (value != null) {
        operands.add(value);
        continue;
      }

      switch (token) {
        case 'Tf':
          final name = operands.whereType<_PdfName>().lastOrNull;
          if (name != null) font = fonts[name.name] ?? _FontInfo.simple;
        case 'Tj':
        case "'":
        case '"':
          final str = operands.whereType<_PdfString>().lastOrNull;
          if (str != null) sink.write(_mapString(str.raw, font));
        case 'TJ':
          final arr = operands.whereType<_PdfArray>().lastOrNull;
          if (arr != null) {
            for (final item in arr.items) {
              if (item is _PdfString) {
                sink.write(_mapString(item.raw, font));
              } else if (item is num && item < -180) {
                sink.write(' ');
              }
            }
          }
        case 'Td':
        case 'TD':
          final nums = operands.whereType<num>().toList();
          if (nums.length >= 2 && nums[nums.length - 1].abs() > 0.1) {
            sink.newline();
          }
        case 'T*':
          sink.newline();
        case 'Tm':
          final nums = operands.whereType<num>().toList();
          if (nums.length >= 6) {
            final y = nums[nums.length - 1].toDouble();
            if (lastY != null && (y - lastY).abs() > 0.5) sink.newline();
            lastY = y;
          }
        case 'ET':
          sink.newline();
      }
      operands.clear();
    }
  }

  String _mapString(String raw, _FontInfo font) {
    final cmap = font.cmap;
    if (cmap == null) return raw;
    final buf = StringBuffer();
    if (font.twoByte) {
      var i = 0;
      while (i + 1 < raw.length) {
        final code = (raw.codeUnitAt(i) << 8) | raw.codeUnitAt(i + 1);
        buf.write(cmap[code] ?? '');
        i += 2;
      }
    } else {
      for (var i = 0; i < raw.length; i++) {
        final code = raw.codeUnitAt(i);
        buf.write(cmap[code] ?? raw[i]);
      }
    }
    return buf.toString();
  }

  // ---------------------------------------------------------------- 词法工具

  static bool _isWhitespace(int c) =>
      c == 0x20 || c == 0x0A || c == 0x0D || c == 0x09 || c == 0x0C || c == 0;

  static bool _isDelimiter(int c) =>
      _isWhitespace(c) || c == 0x28 || c == 0x29 || c == 0x3C || c == 0x3E ||
      c == 0x5B || c == 0x5D || c == 0x7B || c == 0x7D || c == 0x2F || c == 0x25;

  String _hexToBytes(String hex) {
    if (hex.length.isOdd) hex = '0$hex';
    final buf = StringBuffer();
    for (var i = 0; i < hex.length; i += 2) {
      buf.writeCharCode(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return buf.toString();
  }

  ({String text, int next}) _readLiteral(String s, int start) {
    final buf = StringBuffer();
    var depth = 1;
    var i = start + 1;
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      if (c == 0x5C) {
        i++;
        if (i >= s.length) break;
        final e = s.codeUnitAt(i);
        if (e == 0x6E) {
          buf.write('\n');
          i++;
        } else if (e == 0x72) {
          buf.write('\r');
          i++;
        } else if (e == 0x74) {
          buf.write('\t');
          i++;
        } else if (e == 0x62) {
          buf.writeCharCode(8);
          i++;
        } else if (e == 0x66) {
          buf.writeCharCode(12);
          i++;
        } else if (e >= 0x30 && e <= 0x37) {
          var oct = e - 0x30;
          var count = 1;
          i++;
          while (count < 3 && i < s.length) {
            final d = s.codeUnitAt(i);
            if (d < 0x30 || d > 0x37) break;
            oct = oct * 8 + (d - 0x30);
            i++;
            count++;
          }
          buf.writeCharCode(oct & 0xFF);
        } else if (e == 0x0A) {
          i++;
        } else if (e == 0x0D) {
          i++;
          if (i < s.length && s.codeUnitAt(i) == 0x0A) i++;
        } else {
          buf.writeCharCode(e);
          i++;
        }
        continue;
      }
      if (c == 0x28) {
        depth++;
        buf.writeCharCode(c);
        i++;
        continue;
      }
      if (c == 0x29) {
        depth--;
        i++;
        if (depth == 0) break;
        buf.writeCharCode(c);
        continue;
      }
      buf.writeCharCode(c);
      i++;
    }
    return (text: buf.toString(), next: i);
  }

  int _skipDict(String s, int start) {
    var depth = 0;
    var i = start;
    while (i < s.length) {
      if (s.startsWith('<<', i)) {
        depth++;
        i += 2;
        continue;
      }
      if (s.startsWith('>>', i)) {
        depth--;
        i += 2;
        if (depth <= 0) return i;
        continue;
      }
      i++;
    }
    return i;
  }
}
