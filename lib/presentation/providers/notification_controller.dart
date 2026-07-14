import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../data/local/notification_service.dart';
import '../../data/repositories/clinic_repository.dart';
import 'clinic_provider.dart';

/// Günlük randevu bildirimi tercihlerini (açık/kapalı + saat) yönetir ve
/// kalıcı saklar. Değişiklikte önümüzdeki günler için bildirimleri kurar.
class NotificationController extends ChangeNotifier {
  NotificationController(this._repo) {
    _enabled = _repo.getSetting<bool>('notif_enabled') ?? false;
    _hour = _repo.getSetting<int>('notif_hour') ?? 9;
    _minute = _repo.getSetting<int>('notif_min') ?? 0;
  }

  final ClinicRepository _repo;

  bool _enabled = false;
  int _hour = 9;
  int _minute = 0;

  bool get enabled => _enabled;
  TimeOfDay get time => TimeOfDay(hour: _hour, minute: _minute);

  Future<void> setEnabled(bool value, ClinicProvider provider) async {
    _enabled = value;
    await _repo.setSetting('notif_enabled', value);
    if (value) {
      final granted = await NotificationService.requestPermissions();
      if (granted) {
        await reschedule(provider);
      } else {
        // İzin verilmediyse ayarı geri al.
        _enabled = false;
        await _repo.setSetting('notif_enabled', false);
      }
    } else {
      await NotificationService.cancelAll();
    }
    notifyListeners();
  }

  Future<void> setTime(TimeOfDay t, ClinicProvider provider) async {
    _hour = t.hour;
    _minute = t.minute;
    await _repo.setSetting('notif_hour', _hour);
    await _repo.setSetting('notif_min', _minute);
    if (_enabled) await reschedule(provider);
    notifyListeners();
  }

  /// Önümüzdeki 14 gün için, randevusu olan günlerde seçilen saatte bildirim
  /// planlar. Uygulama açılışında ve tercih değişince çağrılır.
  Future<void> reschedule(ClinicProvider provider) async {
    if (!_enabled) {
      await NotificationService.cancelAll();
      return;
    }
    final rnd = Random();
    final items = <({DateTime when, String title, String body})>[];
    final now = DateTime.now();
    for (var i = 0; i < 14; i++) {
      final day = DateTime(now.year, now.month, now.day + i);
      final appts = provider.appointmentsOn(day);
      if (appts.isEmpty) continue;
      final when = DateTime(day.year, day.month, day.day, _hour, _minute);

      final emoji = _emojis[rnd.nextInt(_emojis.length)];
      final dayLabel = i == 0 ? 'Bugün' : Fmt.weekday(day);
      final title = '$emoji  $dayLabel • ${appts.length} randevu';

      final lines = <String>[];
      for (final t in appts.take(6)) {
        final name = provider.patientById(t.patientId)?.name ?? 'Hasta';
        lines.add('🕐 ${Fmt.time(t.appointmentDate)}  $name — ${t.procedureName}');
      }
      if (appts.length > 6) {
        lines.add('… +${appts.length - 6} randevu daha');
      }
      lines.add('\n${_closings[rnd.nextInt(_closings.length)]}');

      items.add((when: when, title: title, body: lines.join('\n')));
    }
    await NotificationService.scheduleItems(items);
  }

  static const _emojis = [
    '🦷', '😁', '🪥', '📅', '🗓️', '⏰', '✨', '💙', '👋', '☀️'
  ];

  static const _closings = [
    'İyi çalışmalar! ✨',
    'Harika bir gün olsun 💙',
    'Hastaların seni bekliyor 🦷',
    'Bugün de gülümset 😁',
    'Kolay gelsin! 👏',
  ];
}
