import 'package:flutter/material.dart';

/// Uygulamanın tüm renk paleti burada tanımlıdır.
///
/// Renkler artık çalışma zamanında (açık / koyu tema) değişebilir.
/// [applyBrightness] çağrıldığında tüm alanlar ilgili palete göre güncellenir;
/// widget ağacı yeniden kurulduğunda yeni renkler otomatik uygulanır.
class AppColors {
  AppColors._();

  static bool _dark = false;
  static bool get isDark => _dark;

  // --- Ana marka renkleri (mavi tonları) ---
  static Color primary = const Color(0xFF2563EB);
  static Color primaryDark = const Color(0xFF1E40AF);
  static Color primaryLight = const Color(0xFF60A5FA);
  static Color accent = const Color(0xFF06B6D4);

  // --- Yüzey / arka plan ---
  static Color background = const Color(0xFFF3F7FE);
  static Color surface = const Color(0xFFFFFFFF);
  static Color surfaceAlt = const Color(0xFFEAF1FD);

  // --- Metin renkleri ---
  static Color textPrimary = const Color(0xFF0F1E36);
  static Color textSecondary = const Color(0xFF64748B);
  static Color textOnPrimary = const Color(0xFFFFFFFF);

  // --- Durum renkleri ---
  static Color success = const Color(0xFF10B981);
  static Color warning = const Color(0xFFF59E0B);
  static Color danger = const Color(0xFFEF4444);
  static Color info = const Color(0xFF3B82F6);

  // --- İkon vurgu renkleri ---
  static Color violet = const Color(0xFF8B5CF6);
  static Color pink = const Color(0xFFEC4899);
  static Color teal = const Color(0xFF14B8A6);
  static Color amber = const Color(0xFFF59E0B);

  // --- Gelir dağılımı (pie chart) ---
  static Color doctorShare = const Color(0xFF2563EB);
  static Color clinicShare = const Color(0xFF06B6D4);

  // --- Diş modeli renkleri ---
  static Color toothIvory = const Color(0xFFFDFDFF);
  static Color toothShade = const Color(0xFFE7EEF9);
  static Color toothOutline = const Color(0xFFB9C6DC);

  // --- Diğer ---
  static Color border = const Color(0xFFDCE6F5);
  static Color shadow = const Color(0x1A2563EB);
  static Color shadowSoft = const Color(0x0F1E293B);

  /// Kliniklere atanan vurgu renkleri (colorIndex ile eşleşir).
  static List<Color> get clinicPalette => [
        primary,
        teal,
        violet,
        pink,
        amber,
        success,
        accent,
        danger,
      ];

  /// Verilen indekse karşılık gelen klinik rengi (paletin içinde döner).
  static Color clinicColor(int index) {
    final p = clinicPalette;
    return p[index % p.length];
  }

  /// Ana degrade (başlık / dashboard kartları için).
  static LinearGradient primaryGradient = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2563EB), Color(0xFF4F8DF7)],
  );

  static LinearGradient accentGradient = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF06B6D4), Color(0xFF22D3EE)],
  );

  /// Bir vurgu rengi için yumuşak degrade üretir.
  static LinearGradient softGradient(Color c) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [c, Color.lerp(c, isDark ? Colors.black : Colors.white, 0.28)!],
      );

  /// Aktif temayı uygular. Widget'lar renkleri build sırasında statik
  /// alanlardan okuduğu için, çağrıdan sonra ağacın yeniden kurulması gerekir.
  static void applyBrightness(bool dark) {
    _dark = dark;
    if (dark) {
      _applyDark();
    } else {
      _applyLight();
    }
  }

  static void _applyLight() {
    primary = const Color(0xFF2563EB);
    primaryDark = const Color(0xFF1E40AF);
    primaryLight = const Color(0xFF60A5FA);
    accent = const Color(0xFF06B6D4);
    background = const Color(0xFFF3F7FE);
    surface = const Color(0xFFFFFFFF);
    surfaceAlt = const Color(0xFFEAF1FD);
    textPrimary = const Color(0xFF0F1E36);
    textSecondary = const Color(0xFF64748B);
    textOnPrimary = const Color(0xFFFFFFFF);
    success = const Color(0xFF10B981);
    warning = const Color(0xFFF59E0B);
    danger = const Color(0xFFEF4444);
    info = const Color(0xFF3B82F6);
    violet = const Color(0xFF8B5CF6);
    pink = const Color(0xFFEC4899);
    teal = const Color(0xFF14B8A6);
    amber = const Color(0xFFF59E0B);
    doctorShare = const Color(0xFF2563EB);
    clinicShare = const Color(0xFF06B6D4);
    toothIvory = const Color(0xFFFDFDFF);
    toothShade = const Color(0xFFE7EEF9);
    toothOutline = const Color(0xFFB9C6DC);
    border = const Color(0xFFDCE6F5);
    shadow = const Color(0x1A2563EB);
    shadowSoft = const Color(0x0F1E293B);
    primaryGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF2563EB), Color(0xFF4F8DF7)],
    );
    accentGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF06B6D4), Color(0xFF22D3EE)],
    );
  }

  static void _applyDark() {
    primary = const Color(0xFF4F8DF7);
    primaryDark = const Color(0xFF1E40AF);
    primaryLight = const Color(0xFF7EAEFB);
    accent = const Color(0xFF22D3EE);
    background = const Color(0xFF0E1626);
    surface = const Color(0xFF172033);
    surfaceAlt = const Color(0xFF1E2A42);
    textPrimary = const Color(0xFFE9EFFA);
    textSecondary = const Color(0xFF94A3B8);
    textOnPrimary = const Color(0xFFFFFFFF);
    success = const Color(0xFF34D399);
    warning = const Color(0xFFFBBF24);
    danger = const Color(0xFFF87171);
    info = const Color(0xFF60A5FA);
    violet = const Color(0xFFA78BFA);
    pink = const Color(0xFFF472B6);
    teal = const Color(0xFF2DD4BF);
    amber = const Color(0xFFFBBF24);
    doctorShare = const Color(0xFF4F8DF7);
    clinicShare = const Color(0xFF22D3EE);
    toothIvory = const Color(0xFFEDF2FB);
    toothShade = const Color(0xFF33415A);
    toothOutline = const Color(0xFF5A6B87);
    border = const Color(0xFF283549);
    shadow = const Color(0x40000000);
    shadowSoft = const Color(0x33000000);
    primaryGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF2E5BC0), Color(0xFF4F8DF7)],
    );
    accentGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0E7490), Color(0xFF22D3EE)],
    );
  }
}
