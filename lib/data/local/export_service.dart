import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/formatters.dart';
import '../models/patient.dart';
import '../models/treatment.dart';

/// İşlem/randevu verilerini biçimlendirilmiş bir .xlsx dosyasına aktarır.
///
/// Ağır olan Excel kodlaması, UI'yı bloke etmemek için bir arka plan
/// isolate'inde (compute) çalışır; on binlerce kayıtta bile ekran donmaz.
class ExportService {
  ExportService._();

  static const _headers = [
    'Tarih',
    'Saat',
    'Hasta',
    'Telefon',
    'İşlem',
    'Dişler',
    'Toplam Ücret',
    'Tahsil Edilen',
    'Kalan',
    'Doktor Payı',
    'Klinik Payı',
    'Taksit',
    'Klinik Tahsil',
    'Doktor Aldı',
    'Not',
  ];

  /// Verilen kayıtlardan bir Excel dosyası üretir ve paylaşım/kaydetme
  /// penceresini açar (kullanıcı nereye kaydedeceğini/göndereceğini seçer).
  /// [sharePositionOrigin] iPad'de paylaşım balonunun konumu için gereklidir.
  static Future<String> exportTreatments({
    required List<Treatment> treatments,
    required List<Patient> patients,
    Rect? sharePositionOrigin,
  }) async {
    final patientById = {for (final p in patients) p.id: p};

    // Hafif tablo (yalnızca String/num) ana thread'de hazırlanır.
    final sorted = [...treatments]
      ..sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));

    final rows = <List<Object?>>[_headers];
    for (final t in sorted) {
      final p = patientById[t.patientId];
      rows.add([
        Fmt.date(t.appointmentDate),
        Fmt.time(t.appointmentDate),
        p?.name ?? '-',
        p?.phone ?? '',
        t.procedureName,
        t.teeth.join(', '),
        t.totalPrice,
        t.collectedAmount,
        t.remaining,
        t.doctorShare,
        t.clinicShare,
        t.installmentCount,
        t.clinicCollected ? 'Evet' : 'Hayır',
        t.doctorPaid ? 'Evet' : 'Hayır',
        t.note,
      ]);
    }

    // Ağır kodlama arka plan isolate'inde.
    final bytes = await compute(_encodeExcel, rows);

    // Paylaşım için geçici (staging) dizine yaz; kullanıcı hedefi seçecek.
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}${Platform.pathSeparator}OzgurDent_${_stamp()}.xlsx';
    await File(path).writeAsBytes(bytes, flush: true);

    // Paylaş / kaydet penceresini aç (iOS "Dosyalara Kaydet", Android hedef seçimi).
    await Share.shareXFiles(
      [
        XFile(
          path,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        )
      ],
      subject: 'ÖzgürDent İşlem Dökümü',
      text: 'ÖzgürDent işlem ve tahsilat dökümü',
      sharePositionOrigin: sharePositionOrigin,
    );

    return path;
  }

  static String _stamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}_${two(n.hour)}${two(n.minute)}';
  }
}

/// Arka plan isolate'inde çalışır: satır verisinden .xlsx bayt dizisi üretir.
/// İlk satır başlık kabul edilir; hücre tipi çalışma zamanı tipinden çözülür.
List<int> _encodeExcel(List<List<Object?>> rows) {
  const widths = [14.0, 8.0, 20.0, 16.0, 20.0, 16.0, 14.0, 14.0, 12.0, 13.0,
    13.0, 8.0, 13.0, 12.0, 30.0];

  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet();
  final sheet = excel['İşlemler'];
  if (defaultSheet != null && defaultSheet != 'İşlemler') {
    excel.delete(defaultSheet);
  }
  excel.setDefaultSheet('İşlemler');

  final headerStyle = CellStyle(
    bold: true,
    fontColorHex: ExcelColor.white,
    backgroundColorHex: ExcelColor.blue,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
  );

  for (var r = 0; r < rows.length; r++) {
    final row = rows[r];
    for (var c = 0; c < row.length; c++) {
      final cell = sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
      final v = row[c];
      cell.value = switch (v) {
        int i => IntCellValue(i),
        double d => DoubleCellValue(d),
        _ => TextCellValue(v?.toString() ?? ''),
      };
      if (r == 0) cell.cellStyle = headerStyle;
    }
  }

  for (var c = 0; c < widths.length; c++) {
    sheet.setColumnWidth(c, widths[c]);
  }

  return excel.save() ?? <int>[];
}
