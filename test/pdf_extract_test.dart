import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:study_notebook/utils/pdf_extract.dart';

String _minimalPdf(String text) {
  return '%PDF-1.4\n'
      '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n'
      '2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n'
      '3 0 obj\n<< /Type /Page /Parent 2 0 R /Resources << /Font << /F1 5 0 R >> >> '
      '/Contents 4 0 R >>\nendobj\n'
      '4 0 obj\n<< /Length 44 >>\nstream\n'
      'BT /F1 12 Tf 72 720 Td ($text) Tj ET\n'
      'endstream\nendobj\n'
      '5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n'
      'trailer\n<< /Root 1 0 R >>\n%%EOF\n';
}

void main() {
  test('未压缩内容流中的文本可以提取', () async {
    final bytes = Uint8List.fromList(utf8.encode(_minimalPdf('Hello PDF')));
    expect(await extractPdfText(bytes), contains('Hello PDF'));
  });

  test('非 PDF 数据不会抛异常', () async {
    final bytes = Uint8List.fromList(utf8.encode('not a pdf at all'));
    expect(await extractPdfText(bytes), isEmpty);
  });
}
