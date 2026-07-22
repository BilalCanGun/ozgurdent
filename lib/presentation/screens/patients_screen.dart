import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/patient.dart';
import '../providers/clinic_provider.dart';
import '../providers/theme_controller.dart';
import '../widgets/app_card.dart';
import '../widgets/common_bits.dart';
import '../widgets/empty_state.dart';
import 'patient_detail_screen.dart';
import 'patient_form_screen.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
    final provider = context.watch<ClinicProvider>();
    final patients = provider.searchPatients(_query);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PageHeader(
                      title: 'Hastalar',
                      subtitle: '${provider.patientCount} kayıtlı hasta',
                      action: FilledButton.icon(
                        onPressed: () => _addPatient(context),
                        icon: const Icon(Icons.person_add_alt_1, size: 20),
                        label: const Text('Yeni'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: const InputDecoration(
                        hintText: 'İsim veya telefon ara...',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: patients.isEmpty
                    ? EmptyState(
                        icon: Icons.people_outline,
                        title: _query.isEmpty
                            ? 'Henüz hasta yok'
                            : 'Sonuç bulunamadı',
                        message: _query.isEmpty
                            ? 'Sağ alttaki butondan ilk hastanı ekle.'
                            : 'Farklı bir arama dene.',
                      )
                    : _buildList(context, provider, patients),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildList(
      BuildContext context, ClinicProvider provider, List<Patient> patients) {
    final wide = Responsive.isWide(context);
    if (wide) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 120),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 420,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 132,
        ),
        itemCount: patients.length,
        itemBuilder: (_, i) => _patientCard(context, provider, patients[i]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
      itemCount: patients.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _patientCard(context, provider, patients[i]),
    );
  }

  Widget _patientCard(
      BuildContext context, ClinicProvider provider, Patient p) {
    final total = provider.patientTotal(p.id);
    final outstanding = provider.patientOutstanding(p.id);
    final count = provider.patientTreatmentCount(p.id);
    final awaitingPayout = provider.patientAwaitingPayout(p.id);

    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PatientDetailScreen(patientId: p.id),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.surfaceAlt,
            child: Text(
              _initials(p.name),
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  p.phone.isNotEmpty ? p.phone : '$count işlem',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Fmt.money(total),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              if (outstanding > 0)
                _tag('Borç ${Fmt.money(outstanding)}', AppColors.warning)
              else if (total > 0)
                _tag('Tahsil edildi', AppColors.success)
              else
                _tag('İşlem yok', AppColors.textSecondary),
              if (awaitingPayout > 0) ...[
                const SizedBox(height: 4),
                _tag('Payın bekliyor', AppColors.violet),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      );

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Future<void> _addPatient(BuildContext context) async {
    final patient = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PatientFormScreen()),
    );
    if (patient != null && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PatientDetailScreen(patientId: patient.id),
        ),
      );
    }
  }
}
