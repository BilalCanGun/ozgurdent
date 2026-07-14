import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/treatment.dart';
import '../providers/clinic_provider.dart';
import '../providers/theme_controller.dart';
import '../widgets/app_card.dart';
import '../widgets/appointment_calendar.dart';
import '../widgets/empty_state.dart';
import '../widgets/payment_editor.dart';
import '../widgets/stat_tile.dart';
import '../widgets/treatment_tile.dart';
import 'patient_detail_screen.dart';
import 'patient_form_screen.dart';
import 'settings_screen.dart';
import '../widgets/week_timetable.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late DateTime _focusedMonth;
  late DateTime _selectedDay;
  late DateTime _weekStart;
  bool _weekMode = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDay = DateTime(now.year, now.month, now.day);
    _weekStart = ClinicProvider.weekStart(now);
  }

  void _setWeekMode(bool week) {
    setState(() {
      _weekMode = week;
      if (week) _weekStart = ClinicProvider.weekStart(_selectedDay);
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>(); // Tema değişince anında yeniden kur.
    final provider = context.watch<ClinicProvider>();
    final now = DateTime.now();
    final today = provider.statsFor(now, StatsRange.day);
    final month = provider.statsFor(now, StatsRange.month);
    final todays = provider.todaysAppointments;
    final selectedAppointments = provider.appointmentsOn(_selectedDay);
    final pending = provider.awaitingDoctorPayout;
    final cols = Responsive.gridColumns(context).clamp(2, 4);

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
            children: [
              _greeting(context, now),
              const SizedBox(height: 20),
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  mainAxisExtent: 150,
                ),
                children: [
                  StatTile(
                    label: 'Bugünkü Kazancın',
                    value: Fmt.money(today.doctor),
                    icon: Icons.today,
                    color: AppColors.primary,
                    subtitle: '${today.procedureCount} işlem',
                  ),
                  StatTile(
                    label: 'Bugünkü Randevu',
                    value: '${todays.length}',
                    icon: Icons.event_available,
                    color: AppColors.accent,
                  ),
                  StatTile(
                    label: 'Bu Ay Kazancın',
                    value: Fmt.money(month.doctor),
                    icon: Icons.calendar_month,
                    color: AppColors.success,
                    subtitle: 'Ciro: ${Fmt.money(month.total)}',
                  ),
                  StatTile(
                    label: 'Bu Ay Bekleyen',
                    value: Fmt.money(month.outstanding),
                    icon: Icons.pending_actions,
                    color: AppColors.warning,
                  ),
                ],
              ),
              if (pending.isNotEmpty) ...[
                const SizedBox(height: 18),
                _payoutWarning(context, provider, pending),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Randevu Takvimi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _addPatient(context),
                    icon: const Icon(Icons.person_add_alt, size: 18),
                    label: const Text('Yeni Hasta'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_weekMode)
                WeekTimetable(
                  weekStart: _weekStart,
                  appointmentsOf: provider.appointmentsOn,
                  patientNameOf: (id) =>
                      provider.patientById(id)?.name ?? 'Hasta',
                  onPrevWeek: () => setState(() => _weekStart =
                      _weekStart.subtract(const Duration(days: 7))),
                  onNextWeek: () => setState(() =>
                      _weekStart = _weekStart.add(const Duration(days: 7))),
                  onTapAppointment: (t) => _openPatient(context, t.patientId),
                  headerAction: _modeToggle(),
                )
              else ...[
                AppointmentCalendar(
                  focusedMonth: _focusedMonth,
                  selectedDay: _selectedDay,
                  countsByDay: provider.appointmentCountsByDay(_focusedMonth),
                  onDaySelected: (d) => setState(() => _selectedDay = d),
                  onMonthChanged: (m) => setState(() => _focusedMonth = m),
                  headerAction: _modeToggle(),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(Icons.event_note, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedDayLabel(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (selectedAppointments.isNotEmpty)
                      Text(
                        '${selectedAppointments.length} randevu',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (selectedAppointments.isEmpty)
                  AppCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.event_busy,
                              color: AppColors.textSecondary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Bu gün için planlanmış randevu yok.',
                              style:
                                  TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...selectedAppointments.map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TreatmentTile(
                          treatment: t,
                          patientName:
                              provider.patientById(t.patientId)?.name ??
                                  'Hasta',
                          onPaymentTap: () => showPaymentEditor(context, t),
                          onTap: () => _openPatient(context, t.patientId),
                        ),
                      )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _selectedDayLabel() {
    final d = _selectedDay;
    return '${Fmt.relativeDay(d)} • ${Fmt.date(d)}';
  }

  /// Takvimi aylık ↔ haftalık görünüm arasında değiştiren buton.
  Widget _modeToggle() {
    return IconButton(
      tooltip: _weekMode ? 'Aylık görünüm' : 'Haftalık görünüm',
      icon: Icon(_weekMode
          ? Icons.calendar_view_month_rounded
          : Icons.calendar_view_week_rounded),
      color: AppColors.primary,
      onPressed: () => _setWeekMode(!_weekMode),
    );
  }

  // ---------------------------------------------------------------------------
  // Uyarı widget'ı: klinik tahsil etti, doktor payını almadı.
  // ---------------------------------------------------------------------------
  Widget _payoutWarning(
    BuildContext context,
    ClinicProvider provider,
    List<Treatment> pending,
  ) {
    final total = provider.awaitingDoctorPayoutTotal;
    return GestureDetector(
      onTap: () => _openPayoutSheet(context, provider),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.violet.withValues(alpha: 0.16),
              AppColors.violet.withValues(alpha: 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.violet.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.violet,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.account_balance_wallet,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Alınmayı bekleyen payın var',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Klinik tahsil etti • ${pending.length} işlem • ${Fmt.money(total)}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.violet),
          ],
        ),
      ),
    );
  }

  void _openPayoutSheet(BuildContext context, ClinicProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.92,
          builder: (ctx, controller) {
            // Alt sayfa provider değişimlerini dinlesin.
            return Consumer<ClinicProvider>(
              builder: (ctx, p, _) {
                final items = p.awaitingDoctorPayout;
                return Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
                      child: Row(
                        children: [
                          Icon(Icons.account_balance_wallet,
                              color: AppColors.violet),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Bekleyen Doktor Payları',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            Fmt.money(p.awaitingDoctorPayoutTotal),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.violet,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (items.isEmpty)
                      const Expanded(
                        child: EmptyState(
                          icon: Icons.verified,
                          title: 'Tümü tamamlandı',
                          message: 'Bekleyen doktor payın kalmadı.',
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          controller: controller,
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) {
                            final t = items[i];
                            return TreatmentTile(
                              treatment: t,
                              patientName:
                                  p.patientById(t.patientId)?.name ?? 'Hasta',
                              onPaymentTap: () => showPaymentEditor(ctx, t),
                              onTap: () {
                                Navigator.pop(ctx);
                                _openPatient(context, t.patientId);
                              },
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _greeting(BuildContext context, DateTime now) {
    return AppCard(
      gradient: AppColors.primaryGradient,
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${Fmt.weekday(now)}, ${Fmt.date(now)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Merhaba Özgür 👋',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bugünün özetine göz at.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _settingsButton(context),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 36,
                  width: 52,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _settingsButton(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.22),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
        child: const Padding(
          padding: EdgeInsets.all(9),
          child: Icon(Icons.settings_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Future<void> _addPatient(BuildContext context) async {
    final patient = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PatientFormScreen()),
    );
    if (patient != null && context.mounted) {
      _openPatient(context, patient.id);
    }
  }

  void _openPatient(BuildContext context, String patientId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PatientDetailScreen(patientId: patientId),
      ),
    );
  }
}
