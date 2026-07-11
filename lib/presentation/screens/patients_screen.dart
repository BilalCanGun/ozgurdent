import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/patient.dart';
import '../providers/clinic_provider.dart';
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
    final provider = context.watch<ClinicProvider>();
    final patients = provider.searchPatients(_query);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addPatient(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Yeni Hasta'),
      ),
      body: Center(
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
                      subtitle: '${provider.patients.length} kayıtlı hasta',
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
    );
  }

  Widget _buildList(
      BuildContext context, ClinicProvider provider, List<Patient> patients) {
    final wide = Responsive.isWide(context);
    if (wide) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 420,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 108,
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
    final unpaid = provider.patientUnpaid(p.id);
    final count = provider.treatmentsForPatient(p.id).length;

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
              style: const TextStyle(
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
                  style: const TextStyle(
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
                  style: const TextStyle(
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
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              if (unpaid > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Borç ${Fmt.money(unpaid)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                    ),
                  ),
                )
              else
                const PaidBadge(paid: true),
            ],
          ),
        ],
      ),
    );
  }

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
