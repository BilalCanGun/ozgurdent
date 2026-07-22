/// Bir işlemin ücret hesaplama modeli.
enum PricingModel {
  /// Toplam ücretin yüzdesi hekime kalır (ör. %30). Kalanı kliniğe.
  percentage,

  /// Hekime sabit net tutar kalır (ör. İmplant 1750₺). Kalanı kliniğe.
  net,

  /// Teknisyen/laboratuvar bedeli düşülür, kalanın yüzdesi hekime kalır.
  percentageAfterLab,
}

extension PricingModelX on PricingModel {
  String get label {
    switch (this) {
      case PricingModel.percentage:
        return 'Yüzde';
      case PricingModel.net:
        return 'Net tutar';
      case PricingModel.percentageAfterLab:
        return 'Teknisyen düşülüp yüzde';
    }
  }

  String get storageKey => name;

  static PricingModel fromKey(String key) => PricingModel.values.firstWhere(
        (e) => e.name == key,
        orElse: () => PricingModel.percentage,
      );
}

/// Katalogtaki bir işlem tanımı (Dolgu, Kanal, İmplant...).
class ProcedureType {
  final String id;
  final String name;

  /// Bu işlem tanımının ait olduğu klinik (boş = yerleşik/klinik-bağımsız).
  final String clinicId;

  final PricingModel model;

  /// [PricingModel.percentage] veya [PricingModel.percentageAfterLab] için oran (0-1).
  final double percentage;

  /// [PricingModel.net] için hekime kalan sabit tutar.
  final double netAmount;

  /// İşlem formunda ücret alanına ön-doldurulacak varsayılan/sabit ücret
  /// (0 = varsayılan yok).
  final double defaultPrice;

  /// Bu işlemde teknisyen bedeli girilmesi gerekiyor mu (kaplama vb.).
  final bool requiresLabFee;

  /// Kullanıcının elle eklediği/özel işlem mi.
  final bool isCustom;

  const ProcedureType({
    required this.id,
    required this.name,
    this.clinicId = '',
    required this.model,
    this.percentage = 0.30,
    this.netAmount = 0,
    this.defaultPrice = 0,
    this.requiresLabFee = false,
    this.isCustom = false,
  });

  ProcedureType copyWith({
    String? id,
    String? name,
    String? clinicId,
    PricingModel? model,
    double? percentage,
    double? netAmount,
    double? defaultPrice,
    bool? requiresLabFee,
  }) =>
      ProcedureType(
        id: id ?? this.id,
        name: name ?? this.name,
        clinicId: clinicId ?? this.clinicId,
        model: model ?? this.model,
        percentage: percentage ?? this.percentage,
        netAmount: netAmount ?? this.netAmount,
        defaultPrice: defaultPrice ?? this.defaultPrice,
        requiresLabFee: requiresLabFee ?? this.requiresLabFee,
        isCustom: isCustom,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'clinicId': clinicId,
        'model': model.name,
        'percentage': percentage,
        'netAmount': netAmount,
        'defaultPrice': defaultPrice,
        'requiresLabFee': requiresLabFee,
        'isCustom': isCustom,
      };

  factory ProcedureType.fromMap(Map<dynamic, dynamic> map) => ProcedureType(
        id: map['id'] as String,
        name: map['name'] as String,
        clinicId: map['clinicId'] as String? ?? '',
        model: PricingModelX.fromKey(map['model'] as String),
        percentage: (map['percentage'] as num?)?.toDouble() ?? 0.30,
        netAmount: (map['netAmount'] as num?)?.toDouble() ?? 0,
        defaultPrice: (map['defaultPrice'] as num?)?.toDouble() ?? 0,
        requiresLabFee: map['requiresLabFee'] as bool? ?? false,
        isCustom: map['isCustom'] as bool? ?? false,
      );

  /// Verilen toplam ücret üzerinden hekim ve klinik paylarını hesaplar.
  ///
  /// [cardCommission] varsa (kredi kartı komisyonu) önce toplam ücretten
  /// düşülür, kalan tutar hekim/klinik olarak paylaştırılır. Böylece komisyon
  /// her iki tarafı orantılı etkiler ve seçilen 3 modelle birlikte çalışır.
  PaymentShares computeShares({
    required double totalPrice,
    double labFee = 0,
    double cardCommission = 0,
    double? overridePercentage,
    double? overrideNetAmount,
  }) {
    // Paylaşılacak taban: komisyon düşülmüş tutar.
    final double base =
        (totalPrice - cardCommission).clamp(0, double.infinity).toDouble();
    double doctor;
    switch (model) {
      case PricingModel.percentage:
        final pct = overridePercentage ?? percentage;
        doctor = base * pct;
        break;
      case PricingModel.net:
        doctor = overrideNetAmount ?? netAmount;
        break;
      case PricingModel.percentageAfterLab:
        final pct = overridePercentage ?? percentage;
        doctor = (base - labFee).clamp(0, double.infinity).toDouble() * pct;
        break;
    }
    if (doctor > base) doctor = base;
    if (doctor < 0) doctor = 0;
    final clinic = base - doctor;
    return PaymentShares(doctor: doctor, clinic: clinic);
  }
}

class PaymentShares {
  final double doctor;
  final double clinic;
  const PaymentShares({required this.doctor, required this.clinic});
}
