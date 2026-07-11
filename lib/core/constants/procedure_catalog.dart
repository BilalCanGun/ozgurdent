import '../../data/models/procedure_type.dart';

/// Klinikte uygulanan standart işlemlerin kataloğu.
///
/// Fiyatlandırma kurallarını buradan güncelleyebilirsin.
/// Yüzdeler "hekime kalan" paydır; kalan kısım kliniğe geçer.
class ProcedureCatalog {
  ProcedureCatalog._();

  static const List<ProcedureType> all = [
    ProcedureType(
      id: 'dolgu',
      name: 'Dolgu',
      model: PricingModel.percentage,
      percentage: 0.30,
    ),
    ProcedureType(
      id: 'kanal',
      name: 'Kanal Tedavisi',
      model: PricingModel.percentage,
      percentage: 0.30,
    ),
    ProcedureType(
      id: 'post',
      name: 'Post',
      model: PricingModel.percentage,
      percentage: 0.30,
    ),
    ProcedureType(
      id: 'cekim',
      name: 'Çekim',
      model: PricingModel.percentage,
      percentage: 0.30,
    ),
    ProcedureType(
      id: 'implant_ustu',
      name: 'İmplant Üstü',
      model: PricingModel.net,
      netAmount: 700,
    ),
    ProcedureType(
      id: 'kaplama_zirkon',
      name: 'Kaplama (Zirkon)',
      model: PricingModel.percentageAfterLab,
      percentage: 0.30,
      requiresLabFee: true,
    ),
    ProcedureType(
      id: 'kaplama_metal',
      name: 'Kaplama (Metal Destekli Porselen)',
      model: PricingModel.percentageAfterLab,
      percentage: 0.30,
      requiresLabFee: true,
    ),
    ProcedureType(
      id: 'implant',
      name: 'İmplant',
      model: PricingModel.net,
      netAmount: 1750,
    ),
    ProcedureType(
      id: 'beyazlatma',
      name: 'Beyazlatma',
      model: PricingModel.percentage,
      percentage: 0.30,
    ),
    ProcedureType(
      id: 'dis_tasi',
      name: 'Diş Taşı Temizliği',
      model: PricingModel.percentage,
      percentage: 0.30,
    ),
    ProcedureType(
      id: 'fissur_sealent',
      name: 'Fissür Sealent',
      model: PricingModel.percentage,
      percentage: 0.30,
    ),
    ProcedureType(
      id: 'kuretaj',
      name: 'Küretaj',
      model: PricingModel.percentage,
      percentage: 0.30,
    ),
    ProcedureType(
      id: 'retreatment',
      name: 'Retreatment',
      model: PricingModel.percentage,
      percentage: 0.30,
    ),
  ];

  /// Manuel/özel işlem için şablon (yüzde kullanıcı tarafından belirlenir).
  static const ProcedureType manual = ProcedureType(
    id: 'manuel',
    name: 'Manuel İşlem',
    model: PricingModel.percentage,
    percentage: 0.30,
    isCustom: true,
  );

  static ProcedureType? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    if (id == manual.id) return manual;
    return null;
  }
}
