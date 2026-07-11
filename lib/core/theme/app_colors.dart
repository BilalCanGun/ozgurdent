import 'package:flutter/material.dart';

/// Uygulamanın tüm renk paleti burada tanımlıdır.
///
/// Renk temasını değiştirmek istersen SADECE bu dosyayı düzenlemen yeterli.
/// Beyaz–mavi modern klinik teması, canlı vurgu renkleriyle.
class AppColors {
  AppColors._();

  // --- Ana marka renkleri (mavi tonları) ---
  static const Color primary = Color(0xFF2563EB); // Canlı mavi
  static const Color primaryDark = Color(0xFF1E40AF);
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color accent = Color(0xFF06B6D4); // Turkuaz vurgu

  // --- Yüzey / arka plan (beyaz tonları) ---
  static const Color background = Color(0xFFF3F7FE); // Çok açık mavi-beyaz
  static const Color surface = Color(0xFFFFFFFF); // Kartlar
  static const Color surfaceAlt = Color(0xFFEAF1FD); // İkincil yüzey

  // --- Metin renkleri ---
  static const Color textPrimary = Color(0xFF0F1E36);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // --- Durum renkleri (canlı) ---
  static const Color success = Color(0xFF10B981); // Ödendi
  static const Color warning = Color(0xFFF59E0B); // Bekleyen
  static const Color danger = Color(0xFFEF4444); // Silme / borç
  static const Color info = Color(0xFF3B82F6);

  // --- İkon vurgu renkleri (canlı, çeşitlilik için) ---
  static const Color violet = Color(0xFF8B5CF6);
  static const Color pink = Color(0xFFEC4899);
  static const Color teal = Color(0xFF14B8A6);
  static const Color amber = Color(0xFFF59E0B);

  // --- Gelir dağılımı (pie chart) ---
  static const Color doctorShare = Color(0xFF2563EB); // Özgür'e kalan
  static const Color clinicShare = Color(0xFF06B6D4); // Kliniğe kalan

  // --- Diş modeli renkleri ---
  static const Color toothIvory = Color(0xFFFDFDFF);
  static const Color toothShade = Color(0xFFE7EEF9);
  static const Color toothOutline = Color(0xFFB9C6DC);

  // --- Diğer ---
  static const Color border = Color(0xFFDCE6F5);
  static const Color shadow = Color(0x1A2563EB);
  static const Color shadowSoft = Color(0x0F1E293B);

  /// Ana degrade (başlık / dashboard kartları için).
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2563EB), Color(0xFF4F8DF7)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF06B6D4), Color(0xFF22D3EE)],
  );

  /// Bir vurgu rengi için yumuşak degrade üretir.
  static LinearGradient softGradient(Color c) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [c, Color.lerp(c, Colors.white, 0.35)!],
      );
}
