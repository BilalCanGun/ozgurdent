import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Günlük randevu bildirimlerini yöneten yerel bildirim servisi (iOS + Android).
///
/// Bildirim içeriği güne özgü olduğu için (o günün randevuları), tekrarlayan
/// tek bir bildirim yerine önümüzdeki günler için ayrı ayrı planlanır ve
/// uygulama her açıldığında yeniden kurulur.
class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _inited = false;

  static Future<void> init() async {
    if (_inited) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Yerel saat dilimi çözülemezse varsayılan (UTC) kullanılır.
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _inited = true;
  }

  /// Bildirim izni ister (iOS ve Android 13+). İzin verildi mi döner.
  static Future<bool> requestPermissions() async {
    await init();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final iosOk =
        await ios?.requestPermissions(alert: true, badge: true, sound: true);
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final andOk = await android?.requestNotificationsPermission();
    return iosOk ?? andOk ?? true;
  }

  static NotificationDetails _details() => const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_appointments',
          'Günlük Randevular',
          channelDescription: 'Seçilen saatte o günün randevu özeti',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(''),
        ),
        iOS: DarwinNotificationDetails(),
      );

  static Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  /// Verilen bildirimleri (geçmişte kalanları atlayarak) planlar; önce
  /// mevcut tüm planlı bildirimleri temizler.
  static Future<void> scheduleItems(
      List<({DateTime when, String title, String body})> items) async {
    await init();
    await _plugin.cancelAll();
    final now = tz.TZDateTime.now(tz.local);
    var id = 0;
    for (final it in items) {
      final when = tz.TZDateTime.from(it.when, tz.local);
      if (!when.isAfter(now)) continue;
      await _plugin.zonedSchedule(
        id++,
        it.title,
        it.body,
        when,
        _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
}
