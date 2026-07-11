import 'package:flutter/material.dart';

/// Uygulamanın tüm renk paleti burada tanımlıdır.
///
/// Renk temasını değiştirmek istersen SADECE bu dosyayı düzenlemen yeterli.
/// Beyaz–mavi modern klinik teması.
class AppColors {
  AppColors._();

  // --- Ana marka renkleri (mavi tonları) ---
  static const Color primary = Color(0xFF1E6BE0); // Ana mavi
  static const Color primaryDark = Color(0xFF1652B0);
  static const Color primaryLight = Color(0xFF4F92F5);
  static const Color accent = Color(0xFF00B8D4); // Turkuaz vurgu

  // --- Yüzey / arka plan (beyaz tonları) ---
  static const Color background = Color(0xFFF4F8FE); // Çok açık mavi-beyaz
  static const Color surface = Color(0xFFFFFFFF); // Kartlar
  static const Color surfaceAlt = Color(0xFFEAF2FD); // İkincil yüzey

  // --- Metin renkleri ---
  static const Color textPrimary = Color(0xFF12233B);
  static const Color textSecondary = Color(0xFF5B6B80);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // --- Durum renkleri ---
  static const Color success = Color(0xFF17B26A); // Ödendi
  static const Color warning = Color(0xFFF79009); // Bekleyen
  static const Color danger = Color(0xFFE5484D); // Silme / borç
  static const Color info = Color(0xFF2E90FA);

  // --- Gelir dağılımı (pie chart) ---
  static const Color doctorShare = Color(0xFF1E6BE0); // Özgür'e kalan
  static const Color clinicShare = Color(0xFF00B8D4); // Kliniğe kalan

  // --- Diğer ---
  static const Color border = Color(0xFFDDE6F2);
  static const Color shadow = Color(0x141E6BE0);

  /// Ana degrade (başlık / dashboard kartları için).
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );
}
