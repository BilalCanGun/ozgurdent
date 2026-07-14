import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/treatment.dart';
import '../providers/clinic_provider.dart';
import '../providers/theme_controller.dart';
import '../widgets/app_card.dart';
import '../widgets/common_bits.dart';
import 'patient_detail_screen.dart';

/// Haftalık ajanda: seçili haftanın her günü için, saat saat hangi hastaya
/// ne yapıldığını detaylı gösterir.
class WeeklyAgendaScreen extends StatefulWidget {
  final DateTime initialDate;
  const WeeklyAgendaScreen({super.key, required this.initialDate});

  @override
  State<WeeklyAgendaScreen> createState() => _WeeklyAgendaScreenState();
}

class _WeeklyAgendaScreenState extends State<WeeklyAgendaScreen> {
  late DateTime _weekStart;

  static const _weekdayNames = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];

  @override
  void initState() {
    super.initState();
    _weekStart = ClinicProvider.weekStart(widget.initialDate);
  }

  void _shift(int weeks) =>
      setState(() => _weekStart = _weekStart.add(Duration(days: 7 * weeks)));

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
    final provider = context.watch<ClinicProvider>();
    final days = [for (int i = 0; i < 7; i++) _weekStart.add(Duration(days: i))];
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final weekTotal = days.fold<int>(
        0, (s, d) => s + provider.appointmentsOn(d).length);

    return Scaffold(
      appBar: AppBar(title: const Text('Haftalık Ajanda')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                _weekNavigator(weekEnd, weekTotal),
                const SizedBox(height: 16),
                for (final day in days) ...[
                  _daySection(context, provider, day),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _weekNavigator(DateTime weekEnd, int total) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _shift(-1),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '${Fmt.dateShort(_weekStart)} – ${Fmt.dateShort(weekEnd)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  total == 0 ? 'Randevu yok' : '$total randevu',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _shift(1),
          ),
        ],
      ),
    );
  }

  Widget _daySection(
      BuildContext context, ClinicProvider provider, DateTime day) {
    final appts = provider.appointmentsOn(day);
    final isToday = _isToday(day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: appts.isEmpty ? AppColors.border : AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _weekdayNames[day.weekday - 1],
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isToday ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              Fmt.dateShort(day),
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            if (isToday) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Bugün',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
            const Spacer(),
            if (appts.isNotEmpty)
              Text(
                '${appts.length}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (appts.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 2),
            child: Text(
              'Randevu yok',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
              ),
            ),
          )
        else
          ...appts.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _agendaTile(context, provider, t),
              )),
      ],
    );
  }

  Widget _agendaTile(
      BuildContext context, ClinicProvider provider, Treatment t) {
    final patient = provider.patientById(t.patientId);
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: patient == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PatientDetailScreen(patientId: t.patientId),
                ),
              ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Saat sütunu
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  Fmt.time(t.appointmentDate),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient?.name ?? 'Hasta',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  t.procedureName,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                if (t.teeth.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ToothChips(t.teeth),
                ],
                if (t.note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    t.note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Fmt.money(t.totalPrice),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              PaymentBadge(treatment: t),
            ],
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}
