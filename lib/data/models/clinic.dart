/// Bir klinik/muayenehane kaydı.
///
/// Her klinik kendi işlem kataloğuna (yüzdelerine) ve işlemlerine sahiptir.
/// Hastalar klinikler arasında ortaktır; işlemler ise [clinicId] ile
/// ait oldukları kliniğe bağlanır.
class Clinic {
  final String id;
  final String name;

  /// Renk paletindeki indeks (arayüzde kliniğe özel vurgu rengi için).
  final int colorIndex;

  final DateTime createdAt;

  const Clinic({
    required this.id,
    required this.name,
    this.colorIndex = 0,
    required this.createdAt,
  });

  Clinic copyWith({String? name, int? colorIndex}) => Clinic(
        id: id,
        name: name ?? this.name,
        colorIndex: colorIndex ?? this.colorIndex,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'colorIndex': colorIndex,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Clinic.fromMap(Map<dynamic, dynamic> map) => Clinic(
        id: map['id'] as String,
        name: map['name'] as String,
        colorIndex: (map['colorIndex'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
}
