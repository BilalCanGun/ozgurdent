import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';

/// Excel (.xlsx) dosyasından ham satırları okur.
///
/// Ağır olan çözme (decode) işlemi arka plan isolate'inde yapılır; her hücre
/// metne çevrilerek döndürülür (tarih/sayı ayrıştırması ana thread'de yapılır,
/// çünkü Türkçe tarih biçimi için locale verisi orada hazırdır).
class ImportService {
  ImportService._();

  static Future<List<List<String>>> readRows(String path) async {
    final bytes = await File(path).readAsBytes();
    return compute(_decodeXlsx, bytes);
  }
}

List<List<String>> _decodeXlsx(Uint8List bytes) {
  final excel = Excel.decodeBytes(bytes);
  if (excel.tables.isEmpty) return const [];
  final sheet = excel.tables.values.first;
  final out = <List<String>>[];
  for (final row in sheet.rows) {
    out.add([for (final cell in row) cell?.value?.toString().trim() ?? '']);
  }
  return out;
}
