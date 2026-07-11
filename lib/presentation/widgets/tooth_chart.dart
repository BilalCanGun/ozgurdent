import 'package:flutter/material.dart';
import '../../core/constants/teeth.dart';
import '../../core/theme/app_colors.dart';

/// FDI sistemine göre interaktif diş şeması.
///
/// Daimi ve süt dişleri arasında geçiş yapılabilir; dişlere dokunarak
/// seçim yapılır. Kontrollü bileşendir: [selected] ve [onChanged] verilir.
class ToothChart extends StatefulWidget {
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  const ToothChart({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<ToothChart> createState() => _ToothChartState();
}

class _ToothChartState extends State<ToothChart> {
  bool _primary = false;

  @override
  void initState() {
    super.initState();
    // Seçili dişlerde süt dişi varsa süt sekmesiyle aç.
    if (widget.selected.any(FdiTeeth.isPrimary) &&
        !widget.selected.any((t) => !FdiTeeth.isPrimary(t))) {
      _primary = true;
    }
  }

  void _toggle(String tooth) {
    final next = Set<String>.from(widget.selected);
    if (next.contains(tooth)) {
      next.remove(tooth);
    } else {
      next.add(tooth);
    }
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final upperRight = _primary
        ? FdiTeeth.primaryUpperRight
        : FdiTeeth.permanentUpperRight;
    final upperLeft =
        _primary ? FdiTeeth.primaryUpperLeft : FdiTeeth.permanentUpperLeft;
    final lowerRight =
        _primary ? FdiTeeth.primaryLowerRight : FdiTeeth.permanentLowerRight;
    final lowerLeft =
        _primary ? FdiTeeth.primaryLowerLeft : FdiTeeth.permanentLowerLeft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _typeToggle(),
        const SizedBox(height: 16),
        _archLabel('Üst Çene'),
        const SizedBox(height: 8),
        _arch(upperRight, upperLeft),
        const SizedBox(height: 18),
        _arch(lowerRight, lowerLeft),
        const SizedBox(height: 8),
        _archLabel('Alt Çene'),
        if (widget.selected.isNotEmpty) ...[
          const SizedBox(height: 16),
          _selectedSummary(),
        ],
      ],
    );
  }

  Widget _typeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _segment('Daimi Dişler', !_primary, () {
            setState(() => _primary = false);
          }),
          _segment('Süt Dişleri', _primary, () {
            setState(() => _primary = true);
          }),
        ],
      ),
    );
  }

  Widget _segment(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: active ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _archLabel(String text) => Center(
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      );

  /// Bir çene (sağ çeyrek + orta çizgi + sol çeyrek). Genişliğe göre ölçeklenir.
  Widget _arch(List<String> right, List<String> left) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final t in right) _tooth(t),
          Container(
            width: 2,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          for (final t in left) _tooth(t),
        ],
      ),
    );
  }

  Widget _tooth(String number) {
    final selected = widget.selected.contains(number);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: GestureDetector(
        onTap: () => _toggle(number),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 38,
          height: 48,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: 1.4,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.water_drop, // Diş benzeri simge
                size: 16,
                color: selected
                    ? Colors.white
                    : AppColors.primary.withValues(alpha: 0.55),
              ),
              const SizedBox(height: 3),
              Text(
                number,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectedSummary() {
    final sorted = widget.selected.toList()..sort();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Seçili dişler: ${sorted.join(', ')}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => widget.onChanged({}),
            child: const Text(
              'Temizle',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
