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
  final PricingModel model;

  /// [PricingModel.percentage] veya [PricingModel.percentageAfterLab] için oran (0-1).
  final double percentage;

  /// [PricingModel.net] için hekime kalan sabit tutar.
  final double netAmount;

  /// Bu işlemde teknisyen bedeli girilmesi gerekiyor mu (kaplama vb.).
  final bool requiresLabFee;

  /// Kullanıcının elle eklediği/özel işlem mi.
  final bool isCustom;

  const ProcedureType({
    required this.id,
    required this.name,
    required this.model,
    this.percentage = 0.30,
    this.netAmount = 0,
    this.requiresLabFee = false,
    this.isCustom = false,
  });

  /// Verilen toplam ücret üzerinden hekim ve klinik paylarını hesaplar.
  PaymentShares computeShares({
    required double totalPrice,
    double labFee = 0,
    double? overridePercentage,
    double? overrideNetAmount,
  }) {
    double doctor;
    switch (model) {
      case PricingModel.percentage:
        final pct = overridePercentage ?? percentage;
        doctor = totalPrice * pct;
        break;
      case PricingModel.net:
        doctor = overrideNetAmount ?? netAmount;
        break;
      case PricingModel.percentageAfterLab:
        final pct = overridePercentage ?? percentage;
        doctor = (totalPrice - labFee).clamp(0, double.infinity) * pct;
        break;
    }
    if (doctor > totalPrice) doctor = totalPrice;
    if (doctor < 0) doctor = 0;
    final clinic = totalPrice - doctor;
    return PaymentShares(doctor: doctor, clinic: clinic);
  }
}

class PaymentShares {
  final double doctor;
  final double clinic;
  const PaymentShares({required this.doctor, required this.clinic});
}
