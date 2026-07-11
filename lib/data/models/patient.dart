/// Hasta kaydı.
class Patient {
  final String id;
  final String name;
  final String phone;
  final String note;
  final DateTime createdAt;

  const Patient({
    required this.id,
    required this.name,
    required this.phone,
    required this.note,
    required this.createdAt,
  });

  Patient copyWith({String? name, String? phone, String? note}) => Patient(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        note: note ?? this.note,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Patient.fromMap(Map<dynamic, dynamic> map) => Patient(
        id: map['id'] as String,
        name: map['name'] as String,
        phone: map['phone'] as String? ?? '',
        note: map['note'] as String? ?? '',
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
}
