import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/patient.dart';
import '../../data/models/treatment.dart';
import '../providers/clinic_provider.dart';
import '../providers/theme_controller.dart';
import '../widgets/app_card.dart';
import '../widgets/appointment_calendar.dart';
import '../widgets/clinic_sheets.dart';
import '../widgets/empty_state.dart';
import '../widgets/gif_refresh_indicator.dart';
import '../widgets/payment_editor.dart';
import '../widgets/stat_tile.dart';
import '../widgets/treatment_tile.dart';
import 'patient_detail_screen.dart';
import 'patient_form_screen.dart';
import 'settings_screen.dart';
import 'treatment_form_screen.dart';
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
  bool _weekMode = true;

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
          child: GifRefreshIndicator(
            onRefresh: () => provider.load(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
              children: [
              _greeting(context, now, provider),
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
                  onTapSlot: (slot) => _addAppointmentAt(context, slot),
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

  Widget _greeting(BuildContext context, DateTime now, ClinicProvider provider) {
    return AppCard(
      gradient: AppColors.primaryGradient,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst şerit: sol üstte ayarlar, sağ üstte logo.
          Row(
            children: [
              _settingsButton(context),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
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
                  height: 32,
                  width: 46,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
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
            'Merhaba Dt. Özgür 👋',
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
          const SizedBox(height: 16),
          _clinicSwitcher(context, provider),
        ],
      ),
    );
  }

  /// Selam kartı içindeki cam görünümlü klinik değiştirme çubuğu.
  Widget _clinicSwitcher(BuildContext context, ClinicProvider provider) {
    final clinic = provider.activeClinic;
    final multi = provider.clinics.length > 1;
    return GestureDetector(
      onTap: () => showClinicSwitcher(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(Icons.local_hospital,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aktif Klinik',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    clinic?.name ?? 'Klinik',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(multi ? Icons.unfold_more : Icons.add,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    multi ? 'Değiştir' : 'Ekle',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

  /// Takvimde boş bir saate dokunulduğunda: önce hasta seç (veya yeni ekle),
  /// sonra o tarih+saate işlem/randevu ekleme ekranını aç.
  Future<void> _addAppointmentAt(BuildContext context, DateTime slot) async {
    final picked = await showModalBottomSheet<_PatientPick>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _PatientPickerSheet(slot: slot),
    );
    if (picked == null || !context.mounted) return;

    Patient? patient = picked.patient;
    if (picked.isNew) {
      patient = await Navigator.of(context).push<Patient>(
        MaterialPageRoute(builder: (_) => const PatientFormScreen()),
      );
    }
    if (patient == null || !context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TreatmentFormScreen(
          patientId: patient!.id,
          initialDate: slot,
        ),
      ),
    );
  }
}

/// Takvim slotu için hasta seçimi sonucu: mevcut hasta ya da "yeni hasta".
class _PatientPick {
  final Patient? patient;
  final bool isNew;
  const _PatientPick.existing(this.patient) : isNew = false;
  const _PatientPick.create()
      : patient = null,
        isNew = true;
}

/// Bir randevu slotu için hasta seçme alt sayfası (arama + yeni hasta).
class _PatientPickerSheet extends StatefulWidget {
  final DateTime slot;
  const _PatientPickerSheet({required this.slot});

  @override
  State<_PatientPickerSheet> createState() => _PatientPickerSheetState();
}

class _PatientPickerSheetState extends State<_PatientPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicProvider>();
    final patients = provider.searchPatients(_query);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        builder: (ctx, controller) => Column(
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
                  Icon(Icons.event_available, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Randevu için hasta seç',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${Fmt.date(widget.slot)} • ${Fmt.time(widget.slot)}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'İsim veya telefon ara...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pop(context, const _PatientPick.create()),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Yeni hasta ekle'),
                ),
              ),
            ),
            Expanded(
              child: patients.isEmpty
                  ? const EmptyState(
                      icon: Icons.people_outline,
                      title: 'Hasta bulunamadı',
                      message: 'Yukarıdan yeni hasta ekleyebilirsin.',
                    )
                  : ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                      itemCount: patients.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final p = patients[i];
                        return AppCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          onTap: () => Navigator.pop(
                              context, _PatientPick.existing(p)),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.surfaceAlt,
                                child: Text(
                                  _initials(p.name),
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (p.phone.isNotEmpty)
                                      Text(
                                        p.phone,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right,
                                  color: AppColors.textSecondary),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
