import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/clinic.dart';
import '../providers/clinic_provider.dart';
import '../providers/theme_controller.dart';
import '../widgets/app_card.dart';
import '../widgets/clinic_sheets.dart';

/// Klinik yönetimi: ekle, düzenle (ad/renk), sil ve aktif kliniği seç.
class ClinicsScreen extends StatelessWidget {
  const ClinicsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
    final provider = context.watch<ClinicProvider>();
    final clinics = provider.clinics;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Klinikler'),
        actions: [
          TextButton.icon(
            onPressed: () => showClinicEditor(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Ekle'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 40),
              children: [
                Text(
                  'Her klinik kendi işlem kataloğuna (yüzdelerine), '
                  'işlemlerine ve istatistiklerine sahiptir. Hastalar tüm '
                  'kliniklerde ortaktır.',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                ...clinics.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _clinicTile(context, provider, c),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _clinicTile(
      BuildContext context, ClinicProvider provider, Clinic c) {
    final active = c.id == provider.activeClinicId;
    final color = AppColors.clinicColor(c.colorIndex);
    final count = provider.clinicTreatmentCount(c.id);
    final canDelete = provider.clinics.length > 1;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => provider.setActiveClinic(c.id),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.local_hospital, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (active) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Aktif',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$count işlem',
                  style: TextStyle(
                      fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
            onPressed: () => showClinicEditor(context, existing: c),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: canDelete ? AppColors.danger : AppColors.textSecondary,
              size: 20,
            ),
            onPressed:
                canDelete ? () => _confirmDelete(context, provider, c) : null,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, ClinicProvider provider, Clinic c) async {
    final count = provider.clinicTreatmentCount(c.id);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kliniği sil'),
        content: Text(
          '"${c.name}" kliniği, bu kliniğe ait $count işlem ve tüm işlem '
          'tanımları (yüzdeler) silinecek. Hastalar silinmez. '
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
    if (ok == true) {
      await provider.deleteClinic(c.id);
    }
  }
}
