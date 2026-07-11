import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../providers/clinic_provider.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/stat_tile.dart';
import '../widgets/treatment_tile.dart';
import 'patient_detail_screen.dart';
import 'patient_form_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicProvider>();
    final now = DateTime.now();
    final today = provider.statsFor(now, StatsRange.day);
    final month = provider.statsFor(now, StatsRange.month);
    final todays = provider.todaysAppointments;
    final upcoming = provider.upcomingAppointments;
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
                  value: Fmt.money(month.unpaid),
                  icon: Icons.pending_actions,
                  color: AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Bugünün Randevuları',
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
            if (todays.isEmpty)
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: const [
                      Icon(Icons.event_busy, color: AppColors.textSecondary),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Bugün için planlanmış randevu yok.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...todays.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TreatmentTile(
                      treatment: t,
                      patientName:
                          provider.patientById(t.patientId)?.name ?? 'Hasta',
                      onTogglePaid: () => provider.togglePaid(t),
                      onTap: () => _openPatient(context, t.patientId),
                    ),
                  )),
            const SizedBox(height: 20),
            const Text(
              'Yaklaşan Randevular',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (upcoming.isEmpty)
              const EmptyState(
                icon: Icons.calendar_today,
                title: 'Yaklaşan randevu yok',
                message: 'Bir hastaya ileri tarihli işlem ekleyerek randevu '
                    'oluşturabilirsin.',
              )
            else
              ...upcoming.take(10).map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TreatmentTile(
                      treatment: t,
                      patientName:
                          provider.patientById(t.patientId)?.name ?? 'Hasta',
                      onTogglePaid: () => provider.togglePaid(t),
                      onTap: () => _openPatient(context, t.patientId),
                    ),
                  )),
          ],
        ),
      ),
      ),
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
          Container(
            padding: const EdgeInsets.all(12),
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
              height: 44,
              width: 60,
              fit: BoxFit.contain,
            ),
          ),
        ],
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
