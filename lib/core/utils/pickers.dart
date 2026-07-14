import 'package:flutter/material.dart';

/// Uygulama genelinde kullanılan, daha kullanışlı saat seçici.
///
/// Klavyeyle doğrudan giriş modunda açılır (saati elle yazmak hızlı), istenirse
/// kadran moduna geçilebilir ve her zaman 24 saat biçimi kullanır.
Future<TimeOfDay?> pickTime(BuildContext context, TimeOfDay initial) {
  return showTimePicker(
    context: context,
    initialTime: initial,
    initialEntryMode: TimePickerEntryMode.input,
    helpText: 'Saat seç',
    hourLabelText: 'Saat',
    minuteLabelText: 'Dakika',
    cancelText: 'Vazgeç',
    confirmText: 'Tamam',
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      );
    },
  );
}
