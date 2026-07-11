/// FDI (Two-Digit) diş numaralandırma sistemi.
///
/// Daimi dişler: çeyrekler 1-4, dişler 1-8 (11-48).
/// Süt dişleri: çeyrekler 5-8, dişler 1-5 (51-85).
///
/// Diziler klinik şemadaki gibi (hastanın karşıdan görünümü) sıralıdır.
class FdiTeeth {
  FdiTeeth._();

  // --- Daimi dişler (32 diş) ---
  // Üst çene: sağ (Q1) -> sol (Q2)
  static const List<String> permanentUpperRight = [
    '18', '17', '16', '15', '14', '13', '12', '11',
  ];
  static const List<String> permanentUpperLeft = [
    '21', '22', '23', '24', '25', '26', '27', '28',
  ];
  // Alt çene: sağ (Q4) -> sol (Q3)
  static const List<String> permanentLowerRight = [
    '48', '47', '46', '45', '44', '43', '42', '41',
  ];
  static const List<String> permanentLowerLeft = [
    '31', '32', '33', '34', '35', '36', '37', '38',
  ];

  // --- Süt dişleri (20 diş) ---
  static const List<String> primaryUpperRight = ['55', '54', '53', '52', '51'];
  static const List<String> primaryUpperLeft = ['61', '62', '63', '64', '65'];
  static const List<String> primaryLowerRight = ['85', '84', '83', '82', '81'];
  static const List<String> primaryLowerLeft = ['71', '72', '73', '74', '75'];

  static bool isPrimary(String tooth) {
    if (tooth.isEmpty) return false;
    final q = tooth[0];
    return q == '5' || q == '6' || q == '7' || q == '8';
  }
}
