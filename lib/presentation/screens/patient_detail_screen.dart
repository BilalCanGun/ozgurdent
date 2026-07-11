import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/patient.dart';
import '../providers/clinic_provider.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/treatment_tile.dart';
import 'patient_form_screen.dart';
import 'treatment_form_screen.dart';

class PatientDetailScreen extends StatelessWidget {
  final String patientId;
  const PatientDetailScreen({super.key, required this.patientId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicProvider>();
    final patient = provider.patientById(patientId);

    if (patient == null) {
      return const Scaffold(
        body: Center(child: Text('Hasta bulunamadı')),
      );
    }

    final treatments = provider.treatmentsForPatient(patientId);
    final total = provider.patientTotal(patientId);
    final unpaid = provider.patientUnpaid(patientId);
    final doctorTotal =
        treatments.fold<double>(0, (s, t) => s + t.doctorShare);

    return Scaffold(
      appBar: AppBar(
        title: Text(patient.name),
        actions: [
          IconButton(
            tooltip: 'Düzenle',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PatientFormScreen(patient: patient),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Sil',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, provider, patient),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addTreatment(context),
        icon: const Icon(Icons.add),
        label: const Text('İşlem / Randevu Ekle'),
      ),
      body: SafeArea(
        child: Center(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
            children: [
              _summaryCard(patient, total, doctorTotal, unpaid),
              if (patient.note.isNotEmpty) ...[
                const SizedBox(height: 14),
                AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.notes_outlined,
                          color: AppColors.textSecondary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          patient.note,
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Text(
                'İşlemler (${treatments.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              if (treatments.isEmpty)
                const EmptyState(
                  icon: Icons.medical_information_outlined,
                  title: 'Henüz işlem yok',
                  message: 'Alttaki butondan bu hastaya işlem veya '
                      'randevu ekle.',
                )
              else
                ...treatments.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TreatmentTile(
                        treatment: t,
                        onTogglePaid: () => provider.togglePaid(t),
                        onTap: () => _editTreatment(context, t.id),
                      ),
                    )),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _summaryCard(
      Patient patient, double total, double doctorTotal, double unpaid) {
    return AppCard(
      gradient: AppColors.primaryGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(
                  _initials(patient.name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (patient.phone.isNotEmpty)
                      Text(
                        patient.phone,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _miniStat('Toplam Ücret', Fmt.money(total)),
              _divider(),
              _miniStat('Sana Kalan', Fmt.money(doctorTotal)),
              _divider(),
              _miniStat('Bekleyen', Fmt.money(unpaid)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );

  Widget _divider() => Container(
        width: 1,
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: Colors.white.withValues(alpha: 0.25),
      );

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  void _addTreatment(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TreatmentFormScreen(patientId: patientId),
      ),
    );
  }

  void _editTreatment(BuildContext context, String treatmentId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TreatmentFormScreen(
          patientId: patientId,
          treatmentId: treatmentId,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, ClinicProvider provider, Patient patient) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hastayı sil'),
        content: Text(
          '${patient.name} ve bu hastaya ait tüm işlemler silinecek. '
          'Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await provider.deletePatient(patient.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}
