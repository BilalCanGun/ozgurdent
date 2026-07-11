import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/treatment.dart';
import '../screens/photo_viewer_screen.dart';
import 'app_card.dart';
import 'common_bits.dart';

/// Bir işlem/randevu kaydını liste içinde gösteren kart.
class TreatmentTile extends StatelessWidget {
  final Treatment treatment;
  final String? patientName;
  final bool showDate;
  final VoidCallback? onTap;
  final VoidCallback? onTogglePaid;

  const TreatmentTile({
    super.key,
    required this.treatment,
    this.patientName,
    this.showDate = true,
    this.onTap,
    this.onTogglePaid,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (patientName != null)
                      Text(
                        patientName!,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    Text(
                      treatment.procedureName,
                      style: TextStyle(
                        fontSize: patientName != null ? 13 : 15,
                        fontWeight: FontWeight.w700,
                        color: patientName != null
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              PaidBadge(paid: treatment.isPaid, onTap: onTogglePaid),
            ],
          ),
          if (treatment.teeth.isNotEmpty) ...[
            const SizedBox(height: 10),
            ToothChips(treatment.teeth),
          ],
          if (treatment.photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            _photoStrip(context),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              if (showDate) ...[
                const Icon(Icons.event,
                    size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 5),
                Text(
                  '${Fmt.relativeDay(treatment.appointmentDate)} • ${Fmt.time(treatment.appointmentDate)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Fmt.money(treatment.totalPrice),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Sana: ${Fmt.money(treatment.doctorShare)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _photoStrip(BuildContext context) {
    final photos = treatment.photos;
    const maxShown = 4;
    final shown = photos.take(maxShown).toList();
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          for (int i = 0; i < shown.length; i++)
            GestureDetector(
              onTap: () => _openViewer(context, i),
              child: Container(
                width: 54,
                height: 54,
                margin: const EdgeInsets.only(right: 8),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(File(shown[i]), fit: BoxFit.cover),
                    if (i == maxShown - 1 && photos.length > maxShown)
                      Container(
                        color: Colors.black.withValues(alpha: 0.5),
                        alignment: Alignment.center,
                        child: Text(
                          '+${photos.length - maxShown}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Icon(Icons.photo_library_outlined,
              size: 18, color: AppColors.textSecondary.withValues(alpha: 0.6)),
        ],
      ),
    );
  }

  void _openViewer(BuildContext context, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoViewerScreen(
          photos: treatment.photos,
          initialIndex: index,
        ),
      ),
    );
  }
}
