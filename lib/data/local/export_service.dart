import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/formatters.dart';
import '../models/patient.dart';
import '../models/procedure_type.dart';
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
    'Kredi Kartı Kom.',
  ];

  /// Detaylı rapor başlıkları (filtreli dışa aktarma için — daha çok sütun).
  static const _detailedHeaders = [
    'Tarih',
    'Saat',
    'Hasta',
    'Telefon',
    'İşlem',
    'Model',
    'Dişler',
    'Toplam Ücret',
    'Kredi Kartı Kom. %',
    'Kredi Kartı Kom. ₺',
    'Tahsil Edilen',
    'Kalan',
    'Doktor Payı',
    'Klinik Payı',
    'Taksit',
    'Durum',
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
        t.cardCommissionRate > 0 ? t.cardCommissionAmount : '',
      ]);
    }

    return _buildAndShare(rows, 'İşlemler', 'OzgurDent');
  }

  /// Detaylı, filtrelenmiş rapor: kullanıcı istatistik/filtre ekranından
  /// seçtiği kayıtları zengin sütunlarla dışa aktarır.
  static Future<String> exportDetailed({
    required List<Treatment> treatments,
    required List<Patient> patients,
    Rect? sharePositionOrigin,
  }) async {
    final patientById = {for (final p in patients) p.id: p};

    final sorted = [...treatments]
      ..sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));

    final rows = <List<Object?>>[_detailedHeaders];
    for (final t in sorted) {
      final p = patientById[t.patientId];
      rows.add([
        Fmt.date(t.appointmentDate),
        Fmt.time(t.appointmentDate),
        p?.name ?? '-',
        p?.phone ?? '',
        t.procedureName,
        t.model.label,
        t.teeth.join(', '),
        t.totalPrice,
        t.cardCommissionRate > 0 ? t.cardCommissionRate * 100 : '',
        t.cardCommissionRate > 0 ? t.cardCommissionAmount : '',
        t.collectedAmount,
        t.remaining,
        t.doctorShare,
        t.clinicShare,
        t.installmentCount,
        _stageLabel(t),
        t.clinicCollected ? 'Evet' : 'Hayır',
        t.doctorPaid ? 'Evet' : 'Hayır',
        t.note,
      ]);
    }

    return _buildAndShare(rows, 'Rapor', 'OzgurDent_Rapor',
        sharePositionOrigin: sharePositionOrigin);
  }

  static String _stageLabel(Treatment t) {
    switch (t.stage) {
      case PaymentStage.pending:
        return 'Bekliyor';
      case PaymentStage.partial:
        return 'Kısmi';
      case PaymentStage.clinicCollected:
        return 'Payın bekliyor';
      case PaymentStage.settled:
        return 'Tamamlandı';
    }
  }

  /// Ortak: satırlardan .xlsx üretir, geçici dizine yazar ve paylaşım açar.
  static Future<String> _buildAndShare(
    List<List<Object?>> rows,
    String sheetName,
    String filePrefix, {
    Rect? sharePositionOrigin,
  }) async {
    final bytes =
        await compute(_encodeExcel, {'sheet': sheetName, 'rows': rows});

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}${Platform.pathSeparator}${filePrefix}_${_stamp()}.xlsx';
    await File(path).writeAsBytes(bytes, flush: true);

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
/// Sütun genişlikleri içeriğe göre otomatik hesaplanır.
List<int> _encodeExcel(Map<String, Object?> payload) {
  final sheetName = payload['sheet'] as String;
  final rows = (payload['rows'] as List).cast<List<Object?>>();

  // İçeriğe göre otomatik sütun genişliği (8..42 aralığında).
  var colCount = 0;
  for (final row in rows) {
    if (row.length > colCount) colCount = row.length;
  }
  final widths = List<double>.filled(colCount, 8);
  for (final row in rows) {
    for (var c = 0; c < row.length; c++) {
      final len = (row[c]?.toString() ?? '').length + 2;
      final w = len.clamp(8, 42).toDouble();
      if (w > widths[c]) widths[c] = w;
    }
  }

  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet();
  final sheet = excel[sheetName];
  if (defaultSheet != null && defaultSheet != sheetName) {
    excel.delete(defaultSheet);
  }
  excel.setDefaultSheet(sheetName);

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
