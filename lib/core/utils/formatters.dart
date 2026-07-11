import 'package:intl/intl.dart';

/// Para ve tarih formatlama yardımcıları (Türkçe / TL).
class Fmt {
  Fmt._();

  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '₺',
    decimalDigits: 0,
  );

  static final NumberFormat _currencyDetailed = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '₺',
    decimalDigits: 2,
  );

  static final DateFormat _date = DateFormat('d MMMM yyyy', 'tr_TR');
  static final DateFormat _dateShort = DateFormat('d MMM', 'tr_TR');
  static final DateFormat _dateTime = DateFormat('d MMMM yyyy • HH:mm', 'tr_TR');
  static final DateFormat _time = DateFormat('HH:mm', 'tr_TR');
  static final DateFormat _weekday = DateFormat('EEEE', 'tr_TR');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy', 'tr_TR');

  /// 1500 -> "₺1.500"
  static String money(num value) => _currency.format(value);

  /// 1500.5 -> "₺1.500,50"
  static String moneyDetailed(num value) => _currencyDetailed.format(value);

  static String date(DateTime d) => _date.format(d);
  static String dateShort(DateTime d) => _dateShort.format(d);
  static String dateTime(DateTime d) => _dateTime.format(d);
  static String time(DateTime d) => _time.format(d);
  static String weekday(DateTime d) => _weekday.format(d);
  static String monthYear(DateTime d) => _monthYear.format(d);

  /// "%30" gibi.
  static String percent(double fraction) =>
      '%${(fraction * 100).toStringAsFixed(fraction * 100 % 1 == 0 ? 0 : 1)}';

  /// Randevu için okunabilir gün etiketi (Bugün / Yarın / tarih).
  static String relativeDay(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return 'Bugün';
    if (diff == 1) return 'Yarın';
    if (diff == -1) return 'Dün';
    return date(d);
  }
}
