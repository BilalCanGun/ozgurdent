import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// İşlem fotoğraflarını cihazda kalıcı olarak saklar.
///
/// Seçilen/çekilen görsel uygulamanın belgeler dizinine kopyalanır;
/// veritabanında sadece dosya yolu tutulur.
class PhotoStorage {
  PhotoStorage._();

  static final _picker = ImagePicker();
  static const _uuid = Uuid();

  /// Kamera veya galeriden görsel seçer, kalıcı klasöre kopyalar,
  /// kaydedilen dosyanın tam yolunu döndürür. İptal edilirse null.
  static Future<String?> capture(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 82,
    );
    if (picked == null) return null;

    final dir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${dir.path}/tedavi_foto');
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    final ext = picked.path.split('.').last;
    final dest = '${photosDir.path}/${_uuid.v4()}.$ext';
    await File(picked.path).copy(dest);
    return dest;
  }

  /// Uygulama içindeki (asset) bir görseli kalıcı foto klasörüne kopyalar.
  /// Demo verisi için kullanılır. Kaydedilen dosyanın yolunu döndürür.
  static Future<String> saveAssetImage(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final dir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${dir.path}/tedavi_foto');
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    final dest = '${photosDir.path}/${_uuid.v4()}.png';
    await File(dest).writeAsBytes(data.buffer.asUint8List());
    return dest;
  }

  static Future<void> delete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // Sessizce geç: dosya zaten yoksa sorun değil.
    }
  }
}
