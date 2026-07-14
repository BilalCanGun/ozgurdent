import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/treatment.dart';

/// Diş numaralarını küçük etiketler halinde gösterir.
class ToothChips extends StatelessWidget {
  final List<String> teeth;
  const ToothChips(this.teeth, {super.key});

  @override
  Widget build(BuildContext context) {
    if (teeth.isEmpty) return const SizedBox.shrink();
    final sorted = [...teeth]..sort();
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        for (final t in sorted)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              t,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}

/// Bir işlemin tahsilat/ödeme aşamasının görsel karşılığı.
class PaymentVisual {
  final String label;
  final IconData icon;
  final Color color;
  const PaymentVisual(this.label, this.icon, this.color);

  static PaymentVisual of(Treatment t) {
    switch (t.stage) {
      case PaymentStage.pending:
        return PaymentVisual('Bekliyor', Icons.schedule, AppColors.warning);
      case PaymentStage.partial:
        return PaymentVisual('Kısmi', Icons.timelapse, AppColors.info);
      case PaymentStage.clinicCollected:
        return PaymentVisual(
            'Payın bekliyor', Icons.account_balance_wallet, AppColors.violet);
      case PaymentStage.settled:
        return PaymentVisual('Tamamlandı', Icons.check_circle, AppColors.success);
    }
  }
}

/// Ödeme/tahsilat durumu rozeti (aşamaya göre renk ve etiket).
class PaymentBadge extends StatelessWidget {
  final Treatment treatment;
  final VoidCallback? onTap;
  const PaymentBadge({super.key, required this.treatment, this.onTap});

  @override
  Widget build(BuildContext context) {
    final v = PaymentVisual.of(treatment);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: v.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(v.icon, size: 14, color: v.color),
            const SizedBox(width: 5),
            Text(
              v.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: v.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Küçük bir "taksit / tahsilat" ilerleme çubuğu (kısmi ödemeler için).
class CollectionProgress extends StatelessWidget {
  final Treatment treatment;
  const CollectionProgress({super.key, required this.treatment});

  @override
  Widget build(BuildContext context) {
    final total = treatment.totalPrice <= 0 ? 1 : treatment.totalPrice;
    final ratio = (treatment.collectedAmount / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Tahsil: ${Fmt.money(treatment.collectedAmount)} / ${Fmt.money(treatment.totalPrice)}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            if (treatment.installmentCount > 1)
              Text(
                '${treatment.installmentCount} taksit',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.info,
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: AppColors.surfaceAlt,
            valueColor: AlwaysStoppedAnimation(
              ratio >= 1 ? AppColors.success : AppColors.info,
            ),
          ),
        ),
      ],
    );
  }
}

/// Ekran başlığı + isteğe bağlı alt başlık ve sağ aksiyon.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}
