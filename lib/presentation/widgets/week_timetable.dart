import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/treatment.dart';
import 'app_card.dart';
import 'common_bits.dart';

/// Haftalık zaman çizelgesi: günler yatay (7 sütun), saatler dikey.
///
/// Randevular başlangıç saatlerine göre ilgili gün+saat hücresine yerleşir.
class WeekTimetable extends StatelessWidget {
  final DateTime weekStart; // Pazartesi
  final List<Treatment> Function(DateTime day) appointmentsOf;
  final String Function(String patientId) patientNameOf;
  final VoidCallback onPrevWeek;
  final VoidCallback onNextWeek;
  final Widget? headerAction;
  final ValueChanged<Treatment> onTapAppointment;

  const WeekTimetable({
    super.key,
    required this.weekStart,
    required this.appointmentsOf,
    required this.patientNameOf,
    required this.onPrevWeek,
    required this.onNextWeek,
    required this.onTapAppointment,
    this.headerAction,
  });

  static const _dayAbbr = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  static const double _gutter = 38;

  @override
  Widget build(BuildContext context) {
    final days = [for (int i = 0; i < 7; i++) weekStart.add(Duration(days: i))];
    // Her gün+saat için randevuları grupla ve saat aralığını belirle.
    final byDayHour = <int, Map<int, List<Treatment>>>{};
    var minHour = 23, maxHour = 0, total = 0;
    for (var d = 0; d < 7; d++) {
      final appts = appointmentsOf(days[d]);
      total += appts.length;
      for (final t in appts) {
        final h = t.appointmentDate.hour;
        if (h < minHour) minHour = h;
        if (h > maxHour) maxHour = h;
        ((byDayHour[d] ??= {})[h] ??= []).add(t);
      }
    }
    if (total == 0) {
      minHour = 9;
      maxHour = 20;
    } else {
      // En az birkaç saatlik pencere göster.
      if (maxHour < minHour + 2) maxHour = minHour + 2;
    }
    final hours = [for (int h = minHour; h <= maxHour; h++) h];
    final weekEnd = weekStart.add(const Duration(days: 6));

    return AppCard(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      child: Column(
        children: [
          _header(weekEnd, total),
          const SizedBox(height: 10),
          _dayHeaderRow(days),
          const SizedBox(height: 4),
          Divider(height: 12, color: AppColors.border),
          for (final h in hours) _hourRow(h, byDayHour),
        ],
      ),
    );
  }

  Widget _header(DateTime weekEnd, int total) {
    return Row(
      children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrevWeek),
        Expanded(
          child: Column(
            children: [
              Text(
                '${Fmt.dateShort(weekStart)} – ${Fmt.dateShort(weekEnd)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                total == 0 ? 'Randevu yok' : '$total randevu',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: onNextWeek,
        ),
        if (headerAction != null) headerAction!,
      ],
    );
  }

  Widget _dayHeaderRow(List<DateTime> days) {
    final now = DateTime.now();
    bool isToday(DateTime d) =>
        d.year == now.year && d.month == now.month && d.day == now.day;
    return Row(
      children: [
        const SizedBox(width: _gutter),
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Column(
              children: [
                Text(
                  _dayAbbr[i],
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color:
                        isToday(days[i])
                            ? AppColors.primary
                            : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isToday(days[i]) ? AppColors.primary : null,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${days[i].day}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color:
                          isToday(days[i])
                              ? Colors.white
                              : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _hourRow(int hour, Map<int, Map<int, List<Treatment>>> byDayHour) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _gutter,
            child: Padding(
              padding: const EdgeInsets.only(top: 4, right: 4),
              child: Text(
                '${hour.toString().padLeft(2, '0')}:00',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          for (var d = 0; d < 7; d++)
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 34),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: AppColors.border.withValues(alpha: 0.6),
                    ),
                    bottom: BorderSide(
                      color: AppColors.border.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                padding: const EdgeInsets.all(2),
                child: Column(
                  children: [
                    for (final t
                        in (byDayHour[d]?[hour] ?? const <Treatment>[]))
                      _block(t),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _block(Treatment t) {
    final v = PaymentVisual.of(t);
    return GestureDetector(
      onTap: () => onTapAppointment(t),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          color: v.color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(6),
          border: Border(left: BorderSide(color: v.color, width: 2.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Fmt.time(t.appointmentDate),
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: v.color,
              ),
            ),
            Text(
              patientNameOf(t.patientId),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
