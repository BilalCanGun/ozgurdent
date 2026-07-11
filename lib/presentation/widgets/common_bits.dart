import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

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
              style: const TextStyle(
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

/// Ödendi / Bekliyor durumu rozeti.
class PaidBadge extends StatelessWidget {
  final bool paid;
  final VoidCallback? onTap;
  const PaidBadge({super.key, required this.paid, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = paid ? AppColors.success : AppColors.warning;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              paid ? Icons.check_circle : Icons.schedule,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 5),
            Text(
              paid ? 'Ödendi' : 'Bekliyor',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
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
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
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
