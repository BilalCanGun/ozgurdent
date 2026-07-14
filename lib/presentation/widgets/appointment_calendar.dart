import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import 'app_card.dart';

/// Randevuları takip etmek için aylık takvim.
///
/// Kontrollü bileşendir: odaklı ay ve seçili gün dışarıdan verilir.
/// Randevu olan günlerde altında nokta/sayı gösterilir.
class AppointmentCalendar extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDay;
  final Map<int, int> countsByDay;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onMonthChanged;

  const AppointmentCalendar({
    super.key,
    required this.focusedMonth,
    required this.selectedDay,
    required this.countsByDay,
    required this.onDaySelected,
    required this.onMonthChanged,
  });

  static const _weekdays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  @override
  Widget build(BuildContext context) {
    final first = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth =
        DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    // Pazartesi = 0 kaydırma.
    final leading = first.weekday - 1;
    final totalCells = leading + daysInMonth;
    final rows = (totalCells / 7.0).ceil();
    final today = DateTime.now();

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        children: [
          _header(),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final w in _weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (int r = 0; r < rows; r++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  for (int c = 0; c < 7; c++)
                    Expanded(child: _cell(r * 7 + c - leading + 1, today)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onMonthChanged(
              DateTime(focusedMonth.year, focusedMonth.month - 1, 1)),
        ),
        Expanded(
          child: Center(
            child: Text(
              Fmt.monthYear(focusedMonth),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onMonthChanged(
              DateTime(focusedMonth.year, focusedMonth.month + 1, 1)),
        ),
      ],
    );
  }

  Widget _cell(int day, DateTime today) {
    if (day < 1 || day > DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day) {
      return const SizedBox(height: 44);
    }
    final date = DateTime(focusedMonth.year, focusedMonth.month, day);
    final count = countsByDay[day] ?? 0;
    final isSelected = date.year == selectedDay.year &&
        date.month == selectedDay.month &&
        date.day == selectedDay.day;
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onDaySelected(date),
      child: Container(
        height: 44,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.primaryGradient : null,
          color: !isSelected && isToday ? AppColors.surfaceAlt : null,
          borderRadius: BorderRadius.circular(12),
          border: isToday && !isSelected
              ? Border.all(color: AppColors.primary, width: 1.2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isSelected || isToday
                    ? FontWeight.w800
                    : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isToday ? AppColors.primary : AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 5,
              child: count == 0
                  ? null
                  : Container(
                      width: count > 2 ? 14 : 5.0 * count + (count - 1) * 2,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : AppColors.accent,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
