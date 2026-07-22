import 'procedure_type.dart';

/// Bir işlemin tahsilat / ödeme durumu (rozetler için).
enum PaymentStage {
  /// Klinik hastadan hiç tahsilat yapmadı.
  pending,

  /// Klinik kısmen tahsil etti (taksit sürüyor).
  partial,

  /// Klinik tamamını tahsil etti fakat doktor payını almadı.
  clinicCollected,

  /// Klinik tahsil etti ve doktor da payını aldı.
  settled,
}

/// Bir hastaya uygulanan/planlanan tek bir işlem kaydı.
/// Aynı zamanda randevu bilgisini (tarih + saat) taşır.
class Treatment {
  final String id;
  final String patientId;

  /// Bu işlemin ait olduğu klinik.
  final String clinicId;

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

  /// Kredi kartı komisyon oranı (0-1). 0 = komisyon yok.
  /// Komisyon önce toplam ücretten düşülür, kalan tutar paylara ayrılır.
  final double cardCommissionRate;

  /// Hesaplanmış paylar (kayıt anında sabitlenir).
  final double doctorShare;
  final double clinicShare;

  /// Randevu tarihi ve saati.
  final DateTime appointmentDate;

  final String note;

  // --- Ödeme / tahsilat ---
  /// Taksit sayısı (1 = peşin).
  final int installmentCount;

  /// Kliniğin hastadan tahsil ettiği tutar (0..totalPrice).
  final double collectedAmount;

  /// Doktor kendi payını klinikten aldı mı.
  final bool doctorPaid;

  /// İşleme ait fotoğrafların dosya yolları (kronolojik).
  final List<String> photos;

  final DateTime createdAt;

  const Treatment({
    required this.id,
    required this.patientId,
    this.clinicId = '',
    required this.procedureId,
    required this.procedureName,
    required this.model,
    required this.teeth,
    required this.totalPrice,
    required this.labFee,
    required this.percentage,
    required this.netAmount,
    this.cardCommissionRate = 0,
    required this.doctorShare,
    required this.clinicShare,
    required this.appointmentDate,
    required this.note,
    this.installmentCount = 1,
    this.collectedAmount = 0,
    this.doctorPaid = false,
    this.photos = const [],
    required this.createdAt,
  });

  // --- Türetilmiş ödeme durumu ---

  /// Kredi kartı komisyon tutarı (toplam ücretten düşülen).
  double get cardCommissionAmount => totalPrice * cardCommissionRate;

  /// Klinik ödemenin tamamını hastadan tahsil etti mi.
  bool get clinicCollected => collectedAmount >= totalPrice - 0.005;

  /// Klinik kısmen tahsil etti mi (taksit sürüyor).
  bool get partiallyCollected =>
      collectedAmount > 0.005 && !clinicCollected;

  /// Hastadan tahsil edilmeyi bekleyen tutar.
  double get remaining {
    final r = totalPrice - collectedAmount;
    return r < 0 ? 0 : r;
  }

  /// Doktorun almayı beklediği pay (klinik tahsil etti ama doktor almadı).
  bool get awaitingDoctorPayout => clinicCollected && !doctorPaid;

  /// İşlem tümüyle kapandı mı (klinik tahsil etti + doktor payını aldı).
  bool get fullySettled => clinicCollected && doctorPaid;

  PaymentStage get stage {
    if (clinicCollected) {
      return doctorPaid ? PaymentStage.settled : PaymentStage.clinicCollected;
    }
    if (partiallyCollected) return PaymentStage.partial;
    return PaymentStage.pending;
  }

  Treatment copyWith({
    String? clinicId,
    String? procedureId,
    String? procedureName,
    PricingModel? model,
    List<String>? teeth,
    double? totalPrice,
    double? labFee,
    double? percentage,
    double? netAmount,
    double? cardCommissionRate,
    double? doctorShare,
    double? clinicShare,
    DateTime? appointmentDate,
    String? note,
    int? installmentCount,
    double? collectedAmount,
    bool? doctorPaid,
    List<String>? photos,
  }) {
    return Treatment(
      id: id,
      patientId: patientId,
      clinicId: clinicId ?? this.clinicId,
      procedureId: procedureId ?? this.procedureId,
      procedureName: procedureName ?? this.procedureName,
      model: model ?? this.model,
      teeth: teeth ?? this.teeth,
      totalPrice: totalPrice ?? this.totalPrice,
      labFee: labFee ?? this.labFee,
      percentage: percentage ?? this.percentage,
      netAmount: netAmount ?? this.netAmount,
      cardCommissionRate: cardCommissionRate ?? this.cardCommissionRate,
      doctorShare: doctorShare ?? this.doctorShare,
      clinicShare: clinicShare ?? this.clinicShare,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      note: note ?? this.note,
      installmentCount: installmentCount ?? this.installmentCount,
      collectedAmount: collectedAmount ?? this.collectedAmount,
      doctorPaid: doctorPaid ?? this.doctorPaid,
      photos: photos ?? this.photos,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'patientId': patientId,
        'clinicId': clinicId,
        'procedureId': procedureId,
        'procedureName': procedureName,
        'model': model.name,
        'teeth': teeth,
        'totalPrice': totalPrice,
        'labFee': labFee,
        'percentage': percentage,
        'netAmount': netAmount,
        'cardCommissionRate': cardCommissionRate,
        'doctorShare': doctorShare,
        'clinicShare': clinicShare,
        'appointmentDate': appointmentDate.toIso8601String(),
        'note': note,
        'installmentCount': installmentCount,
        'collectedAmount': collectedAmount,
        'doctorPaid': doctorPaid,
        'photos': photos,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Treatment.fromMap(Map<dynamic, dynamic> map) {
    final total = (map['totalPrice'] as num).toDouble();
    // Eski kayıt uyumluluğu: tek 'isPaid' bayrağı vardı.
    final legacyPaid = map['isPaid'] as bool?;
    final collected = (map['collectedAmount'] as num?)?.toDouble() ??
        (legacyPaid == true ? total : 0);
    final doctorPaid =
        map['doctorPaid'] as bool? ?? (legacyPaid == true);

    return Treatment(
      id: map['id'] as String,
      patientId: map['patientId'] as String,
      clinicId: map['clinicId'] as String? ?? '',
      procedureId: map['procedureId'] as String,
      procedureName: map['procedureName'] as String,
      model: PricingModelX.fromKey(map['model'] as String),
      teeth: (map['teeth'] as List).map((e) => e.toString()).toList(),
      totalPrice: total,
      labFee: (map['labFee'] as num?)?.toDouble() ?? 0,
      percentage: (map['percentage'] as num?)?.toDouble() ?? 0,
      netAmount: (map['netAmount'] as num?)?.toDouble() ?? 0,
      cardCommissionRate:
          (map['cardCommissionRate'] as num?)?.toDouble() ?? 0,
      doctorShare: (map['doctorShare'] as num).toDouble(),
      clinicShare: (map['clinicShare'] as num).toDouble(),
      appointmentDate: DateTime.parse(map['appointmentDate'] as String),
      note: map['note'] as String? ?? '',
      installmentCount: (map['installmentCount'] as num?)?.toInt() ?? 1,
      collectedAmount: collected,
      doctorPaid: doctorPaid,
      photos: (map['photos'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
