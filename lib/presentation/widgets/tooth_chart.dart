import 'package:flutter/material.dart';
import '../../core/constants/teeth.dart';
import '../../core/theme/app_colors.dart';
import 'tooth_model.dart';

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

  /// Bir çene (sağ çeyrek + orta çizgi + sol çeyrek).
  /// Dişler ekran genişliğine göre mümkün olduğunca büyük çizilir ve tümü sığar.
  Widget _arch(List<String> right, List<String> left) {
    final count = right.length + left.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 3.0;
        const dividerW = 10.0;
        final toothW =
            ((constraints.maxWidth - dividerW) / count - gap).clamp(16.0, 66.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final t in right) _tooth(t, toothW, gap),
            Container(
              width: 2,
              height: toothW * 1.6,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            for (final t in left) _tooth(t, toothW, gap),
          ],
        );
      },
    );
  }

  Widget _tooth(String number, double w, double gap) {
    final selected = widget.selected.contains(number);
    final fontSize = (w * 0.32).clamp(9.0, 14.0);
    return GestureDetector(
      onTap: () => _toggle(number),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: w,
        margin: EdgeInsets.symmetric(horizontal: gap / 2),
        padding: EdgeInsets.symmetric(vertical: w * 0.14, horizontal: 2),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.primaryGradient : null,
          color: selected ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(w * 0.26),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: 1.6,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 12,
                    offset: Offset(0, 5),
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ToothModelIcon(
                number: number, selected: selected, size: w * 0.82),
            SizedBox(height: w * 0.08),
            Text(
              number,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
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
