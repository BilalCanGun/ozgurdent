import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../data/repositories/clinic_repository.dart';

/// Açık / koyu tema tercihini yönetir ve kalıcı olarak saklar (Hive meta_box).
///
/// Tema değiştiğinde [AppColors] paleti güncellenir ve dinleyiciler
/// (MaterialApp + `context.watch<ThemeController>()` yapan tüm ekranlar)
/// yeniden kurularak yeni renkler anında yansır.
class ThemeController extends ChangeNotifier {
  ThemeController(this._repo) {
    _dark = _repo.getSetting<bool>(_key) ?? false;
    AppColors.applyBrightness(_dark);
    _applySystemUi();
  }

  static const String _key = 'dark_mode';
  final ClinicRepository _repo;

  bool _dark = false;
  bool get isDark => _dark;

  ThemeMode get mode => _dark ? ThemeMode.dark : ThemeMode.light;

  Future<void> setDark(bool value) async {
    if (_dark == value) return;
    _dark = value;
    AppColors.applyBrightness(_dark);
    _applySystemUi();
    await _repo.setSetting(_key, _dark);
    notifyListeners();
  }

  Future<void> toggle() => setDark(!_dark);

  /// Durum çubuğu / sistem çubuğu ikon renklerini temaya göre ayarlar.
  void _applySystemUi() {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            _dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: _dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness:
            _dark ? Brightness.light : Brightness.dark,
      ),
    );
  }
}
