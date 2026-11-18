library;

/// 轻量纯 Dart PDF 文本提取。
///
/// 解析 PDF Content Stream 中的 BT...ET 文本块，提取 Tj / TJ 操作符的字符串。
/// 不处理复杂编码（如 CID 字体、内嵌字体映射），但对于大多数课程 PDF
/// （系统字体、直接编码）能正确提取出正文。

import 'dart:convert';
import 'dart:typed_data';

/// 从原始 PDF 字节中提取可见文本。
String extractPdfText(Uint8List bytes) {
  // 转为 ISO-8859-1（单字节）字符串，保持所有原始字节值不变
  final String raw = latin1.decode(bytes);
  final buffer = StringBuffer();

  // 逐段找 BT ... ET 块
  final btEtRe = RegExp(r'BT(.*?)ET', multiLine: true, dotAll: true);
  for (final match in btEtRe.allMatches(raw)) {
    final block = match.group(1)!;
    _extractFromBlock(block, buffer);
  }

  return buffer.toString().trim();
}

void _extractFromBlock(String block, StringBuffer buffer) {
  // Tj 操作符: (string) Tj  —— 括号里是 PDF string
  final tjRe = RegExp(r'\(((?:[^()\\]|\\.)*)\)\s*Tj');
  for (final m in tjRe.allMatches(block)) {
    buffer.write(_unescape(m.group(1)!));
    buffer.write('\n');
  }

  // TJ 操作符: [(a) (b) ...] TJ  —— 数组内的括号字符串
  final tjArrayRe = RegExp(r'\[([^\]]*)\]\s*TJ', dotAll: true);
  for (final m in tjArrayRe.allMatches(block)) {
    final array = m.group(1)!;
    final strRe = RegExp(r'\(((?:[^()\\]|\\.)*)\)');
    for (final sm in strRe.allMatches(array)) {
      buffer.write(_unescape(sm.group(1)!));
    }
    buffer.write('\n');
  }
}

/// 处理 PDF string 的转义：\(  \)  \\  \n  \r  \t
String _unescape(String s) {
  final out = StringBuffer();
  var i = 0;
  while (i < s.length) {
    final c = s[i];
    if (c == r'\' && i + 1 < s.length) {
      final next = s[i + 1];
      switch (next) {
        case 'n':
          out.write('\n');
          break;
        case 'r':
          out.write('\r');
          break;
        case 't':
          out.write('\t');
          break;
        case '(':
          out.write('(');
          break;
        case ')':
          out.write(')');
          break;
        case r'\':
          out.write('\\');
          break;
        case '0':
        case '1':
        case '2':
        case '3':
        case '4':
        case '5':
        case '6':
        case '7':
          // 八进制
          while (i < s.length &&
              s[i] == r'\' &&
              i + 1 < s.length &&
              '01234567'.contains(s[i + 1])) {
            i += 1;
            var oct = '';
            while (i < s.length && oct.length < 3 && '01234567'.contains(s[i])) {
              oct += s[i];
              i += 1;
            }
            final code = int.tryParse(oct, radix: 8);
            if (code != null) out.writeCharCode(code);
          }
          continue;
        default:
          out.write(next);
          break;
      }
      i += 2;
    } else {
      out.write(c);
      i += 1;
    }
  }
  return out.toString();
}
