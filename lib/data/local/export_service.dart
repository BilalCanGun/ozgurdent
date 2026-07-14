import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/formatters.dart';
import '../models/patient.dart';
import '../models/treatment.dart';

/// İşlem/randevu verilerini biçimlendirilmiş bir .xlsx dosyasına aktarır.
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

    // Başlık satırı.
    for (var c = 0; c < _headers.length; c++) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
      cell.value = TextCellValue(_headers[c]);
      cell.cellStyle = headerStyle;
    }

    final sorted = [...treatments]
      ..sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));

    var row = 1;
    for (final t in sorted) {
      final p = patientById[t.patientId];
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = TextCellValue(Fmt.date(t.appointmentDate));
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = TextCellValue(Fmt.time(t.appointmentDate));
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          .value = TextCellValue(p?.name ?? '-');
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
          .value = TextCellValue(p?.phone ?? '');
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
          .value = TextCellValue(t.procedureName);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
          .value = TextCellValue(t.teeth.join(', '));
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
          .value = DoubleCellValue(t.totalPrice);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
          .value = DoubleCellValue(t.collectedAmount);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
          .value = DoubleCellValue(t.remaining);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row))
          .value = DoubleCellValue(t.doctorShare);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row))
          .value = DoubleCellValue(t.clinicShare);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: row))
          .value = IntCellValue(t.installmentCount);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: row))
          .value = TextCellValue(t.clinicCollected ? 'Evet' : 'Hayır');
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: row))
          .value = TextCellValue(t.doctorPaid ? 'Evet' : 'Hayır');
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 14, rowIndex: row))
          .value = TextCellValue(t.note);
      row++;
    }

    // Sütun genişlikleri.
    const widths = [14.0, 8.0, 20.0, 16.0, 20.0, 16.0, 14.0, 14.0, 12.0, 13.0,
      13.0, 8.0, 13.0, 12.0, 30.0];
    for (var c = 0; c < widths.length; c++) {
      sheet.setColumnWidth(c, widths[c]);
    }

    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('Excel dosyası oluşturulamadı.');
    }

    // Paylaşım için geçici (staging) dizine yaz; kullanıcı hedefi seçecek.
    final dir = await getTemporaryDirectory();
    final stamp = _stamp();
    final path = '${dir.path}${Platform.pathSeparator}OzgurDent_$stamp.xlsx';
    final file = File(path);
    await file.writeAsBytes(bytes);

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
