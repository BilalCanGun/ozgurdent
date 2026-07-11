import 'procedure_type.dart';

/// Bir hastaya uygulanan/planlanan tek bir işlem kaydı.
/// Aynı zamanda randevu bilgisini (tarih + saat) taşır.
class Treatment {
  final String id;
  final String patientId;

  /// Katalog işleminin id'si (dolgu, implant, manuel...).
  final String procedureId;

  /// İşlem adı (katalog değişse bile kayıt bozulmasın diye snapshot).
  final String procedureName;

  final PricingModel model;

  /// Seçili dişler (FDI numaraları, ör. "11", "36", "51").
  final List<String> teeth;

  /// Hastadan alınan toplam ücret.
  final double totalPrice;

  /// Teknisyen / laboratuvar bedeli (kaplama vb.).
  final double labFee;

  /// Bu işlem için kullanılan oran (yüzde modelinde). 0-1.
  final double percentage;

  /// Net model için hekime kalan sabit tutar.
  final double netAmount;

  /// Hesaplanmış paylar (kayıt anında sabitlenir).
  final double doctorShare;
  final double clinicShare;

  /// Randevu tarihi ve saati.
  final DateTime appointmentDate;

  final String note;
  final bool isPaid;

  /// İşleme ait fotoğrafların dosya yolları (kronolojik).
  final List<String> photos;

  final DateTime createdAt;

  const Treatment({
    required this.id,
    required this.patientId,
    required this.procedureId,
    required this.procedureName,
    required this.model,
    required this.teeth,
    required this.totalPrice,
    required this.labFee,
    required this.percentage,
    required this.netAmount,
    required this.doctorShare,
    required this.clinicShare,
    required this.appointmentDate,
    required this.note,
    required this.isPaid,
    this.photos = const [],
    required this.createdAt,
  });

  Treatment copyWith({
    String? procedureId,
    String? procedureName,
    PricingModel? model,
    List<String>? teeth,
    double? totalPrice,
    double? labFee,
    double? percentage,
    double? netAmount,
    double? doctorShare,
    double? clinicShare,
    DateTime? appointmentDate,
    String? note,
    bool? isPaid,
    List<String>? photos,
  }) {
    return Treatment(
      id: id,
      patientId: patientId,
      procedureId: procedureId ?? this.procedureId,
      procedureName: procedureName ?? this.procedureName,
      model: model ?? this.model,
      teeth: teeth ?? this.teeth,
      totalPrice: totalPrice ?? this.totalPrice,
      labFee: labFee ?? this.labFee,
      percentage: percentage ?? this.percentage,
      netAmount: netAmount ?? this.netAmount,
      doctorShare: doctorShare ?? this.doctorShare,
      clinicShare: clinicShare ?? this.clinicShare,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      note: note ?? this.note,
      isPaid: isPaid ?? this.isPaid,
      photos: photos ?? this.photos,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'patientId': patientId,
        'procedureId': procedureId,
        'procedureName': procedureName,
        'model': model.name,
        'teeth': teeth,
        'totalPrice': totalPrice,
        'labFee': labFee,
        'percentage': percentage,
        'netAmount': netAmount,
        'doctorShare': doctorShare,
        'clinicShare': clinicShare,
        'appointmentDate': appointmentDate.toIso8601String(),
        'note': note,
        'isPaid': isPaid,
        'photos': photos,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Treatment.fromMap(Map<dynamic, dynamic> map) => Treatment(
        id: map['id'] as String,
        patientId: map['patientId'] as String,
        procedureId: map['procedureId'] as String,
        procedureName: map['procedureName'] as String,
        model: PricingModelX.fromKey(map['model'] as String),
        teeth: (map['teeth'] as List).map((e) => e.toString()).toList(),
        totalPrice: (map['totalPrice'] as num).toDouble(),
        labFee: (map['labFee'] as num?)?.toDouble() ?? 0,
        percentage: (map['percentage'] as num?)?.toDouble() ?? 0,
        netAmount: (map['netAmount'] as num?)?.toDouble() ?? 0,
        doctorShare: (map['doctorShare'] as num).toDouble(),
        clinicShare: (map['clinicShare'] as num).toDouble(),
        appointmentDate: DateTime.parse(map['appointmentDate'] as String),
        note: map['note'] as String? ?? '',
        isPaid: map['isPaid'] as bool? ?? false,
        photos: (map['photos'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
}
