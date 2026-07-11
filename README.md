# ÖzgürDent 🦷

Diş kliniği için **hasta takip, işlem ve gelir yönetimi** uygulaması (Flutter).
Login yok, tüm veriler cihazda yerel olarak (Hive) saklanır. Telefon ve tablet
için responsive tasarım, beyaz–mavi modern tema.

## Özellikler

- **Hasta yönetimi:** ekleme/düzenleme/silme, arama, telefon ve not.
- **İşlem & randevu:** her işleme tarih + saat (bugün veya ileri tarihli randevu).
- **FDI diş seçimi:** daimi (11–48) ve süt dişleri (51–85) için interaktif şema.
- **Otomatik ücret paylaşımı:** her işlemde "sana kalan" ve "kliniğe kalan"
  otomatik hesaplanır (canlı önizleme).
- **Ödeme durumu:** ödendi / bekliyor takibi, hasta bazlı borç.
- **İstatistik:** gün / ay / yıl bazlı toplam kazanç, işlem sayısı ve pie chart ile
  gelir dağılımı (sana / kliniğe).

## Fiyatlandırma Kuralları

Yüzdeler **hekime (Özgür'e) kalan** paydır; kalan kısım kliniğe geçer.
Kurallar `lib/core/constants/procedure_catalog.dart` dosyasından düzenlenebilir.

| İşlem | Kural |
|------|-------|
| Dolgu, Kanal, Post, Çekim, Beyazlatma, Diş Taşı Temizliği, Fissür Sealent, Küretaj, Retreatment | %30 |
| İmplant Üstü | Net 700 ₺ |
| İmplant | Net 1750 ₺ |
| Kaplama (Zirkon / Metal Destekli Porselen) | Teknisyen bedeli düşülür, kalanın %30'u |
| Manuel İşlem | Yüzdeyi sen belirlersin |

## Mimari (Katmanlı)

```
lib/
├── core/                      # Ortak altyapı
│   ├── theme/                 # app_colors.dart (renkler), app_theme.dart
│   ├── constants/             # procedure_catalog.dart, teeth.dart (FDI)
│   └── utils/                 # formatters.dart (₺/tarih), responsive.dart
├── data/                      # Veri katmanı
│   ├── models/                # patient, treatment, procedure_type
│   ├── local/                 # hive_boxes.dart (yerel DB)
│   └── repositories/          # clinic_repository.dart
└── presentation/              # Arayüz katmanı
    ├── providers/             # clinic_provider.dart (state, Provider)
    ├── widgets/               # tooth_chart, stat_tile, treatment_tile ...
    └── screens/               # dashboard, patients, patient_detail,
                               # patient_form, treatment_form, statistics
```

- **State yönetimi:** `provider` (ChangeNotifier).
- **Veritabanı:** `hive` — kayıtlar Map (JSON) olarak, kod üretimi gerektirmeden.
- **Grafik:** `fl_chart`.

## Temayı Değiştirme

Renkleri değiştirmek için tek dosya yeterli:
`lib/core/theme/app_colors.dart` → `primary`, `accent`, `background` vb.

## Çalıştırma

```bash
flutter pub get
flutter run                 # bağlı cihaz/emülatörde
flutter test                # birim testleri (ücret hesaplama)
flutter build apk           # Android
flutter build web           # Web
```

Desteklenen hedefler: Android, iOS, Web, Windows, macOS, Linux.
Tablet ve telefon için otomatik responsive yerleşim (yan menü / alt menü).
