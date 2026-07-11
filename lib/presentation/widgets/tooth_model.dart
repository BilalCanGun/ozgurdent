import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum ToothType { incisor, canine, premolar, molar }

/// Bir FDI diş numarasının tipini ve çenesini çözer.
class ToothInfo {
  final ToothType type;
  final bool upper; // Üst çene mi
  const ToothInfo(this.type, this.upper);

  factory ToothInfo.fromFdi(String number) {
    final q = int.tryParse(number.isNotEmpty ? number[0] : '1') ?? 1;
    final pos = int.tryParse(number.length > 1 ? number[1] : '1') ?? 1;
    final upper = q == 1 || q == 2 || q == 5 || q == 6;
    final primary = q >= 5;

    ToothType type;
    if (primary) {
      // Süt dişleri: 1-2 kesici, 3 köpek, 4-5 azı
      if (pos <= 2) {
        type = ToothType.incisor;
      } else if (pos == 3) {
        type = ToothType.canine;
      } else {
        type = ToothType.molar;
      }
    } else {
      if (pos <= 2) {
        type = ToothType.incisor;
      } else if (pos == 3) {
        type = ToothType.canine;
      } else if (pos <= 5) {
        type = ToothType.premolar;
      } else {
        type = ToothType.molar;
      }
    }
    return ToothInfo(type, upper);
  }
}

/// Diş tipine göre gerçekçi (stilize) diş modeli çizen ikon.
class ToothModelIcon extends StatelessWidget {
  final String number;
  final bool selected;
  final double size;

  const ToothModelIcon({
    super.key,
    required this.number,
    required this.selected,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final info = ToothInfo.fromFdi(number);
    return CustomPaint(
      size: Size(size, size * 1.28),
      painter: _ToothPainter(info: info, selected: selected),
    );
  }
}

class _ToothPainter extends CustomPainter {
  final ToothInfo info;
  final bool selected;

  _ToothPainter({required this.info, required this.selected});

  @override
  void paint(Canvas canvas, Size size) {
    // Üst çene: kökler yukarı; alt çene: dikey çevir (kökler aşağı).
    if (!info.upper) {
      canvas.translate(0, size.height);
      canvas.scale(1, -1);
    }

    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = selected ? Colors.white : AppColors.toothIvory;
    final shade = Paint()
      ..style = PaintingStyle.fill
      ..color = selected
          ? Colors.white.withValues(alpha: 0.35)
          : AppColors.toothShade;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = selected ? Colors.white : AppColors.toothOutline;

    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    final crownTop = h * 0.44;
    final crownBottom = h * 0.97;
    final rootTop = h * 0.05;

    final cwFactor = switch (info.type) {
      ToothType.incisor => 0.60,
      ToothType.canine => 0.54,
      ToothType.premolar => 0.66,
      ToothType.molar => 0.88,
    };
    final cw = w * cwFactor;
    final left = cx - cw / 2;
    final right = cx + cw / 2;

    final rootCount = switch (info.type) {
      ToothType.incisor => 1,
      ToothType.canine => 1,
      ToothType.premolar => 2,
      ToothType.molar => 3,
    };

    // --- Kökler ---
    final rootPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = selected
          ? Colors.white.withValues(alpha: 0.9)
          : const Color(0xFFF3F7FD);
    final rootSpan = cw * 0.82;
    final rootW = rootSpan / rootCount * 0.78;
    for (int i = 0; i < rootCount; i++) {
      final t = rootCount == 1 ? 0.5 : i / (rootCount - 1);
      final x = (cx - rootSpan / 2) + t * rootSpan;
      final tip = rootTop + (i.isOdd ? h * 0.03 : 0); // hafif düzensizlik
      final rp = Path()
        ..moveTo(x - rootW / 2, crownTop + h * 0.02)
        ..quadraticBezierTo(
            x - rootW * 0.35, (tip + crownTop) / 2, x, tip)
        ..quadraticBezierTo(
            x + rootW * 0.35, (tip + crownTop) / 2, x + rootW / 2,
            crownTop + h * 0.02)
        ..close();
      canvas.drawPath(rp, rootPaint);
      canvas.drawPath(rp, outline);
    }

    // --- Kron (crown) ---
    final crown = Path();
    const rTop = 8.0;
    crown.moveTo(left, crownTop + rTop);
    crown.quadraticBezierTo(left, crownTop, left + rTop, crownTop);
    crown.lineTo(right - rTop, crownTop);
    crown.quadraticBezierTo(right, crownTop, right, crownTop + rTop);

    final valleyY = crownBottom - h * 0.06;
    crown.lineTo(right, valleyY);

    switch (info.type) {
      case ToothType.incisor:
        // Yumuşak, düz kesici kenar
        crown.quadraticBezierTo(
            cx, crownBottom + h * 0.02, left, valleyY);
        break;
      case ToothType.canine:
        // Sivri tek tümsek (V)
        crown.lineTo(cx + cw * 0.06, crownBottom);
        crown.lineTo(cx - cw * 0.06, crownBottom);
        crown.lineTo(left, valleyY);
        break;
      case ToothType.premolar:
        _scallops(crown, left, right, valleyY, crownBottom, 2);
        break;
      case ToothType.molar:
        _scallops(crown, left, right, valleyY, crownBottom, 4);
        break;
    }

    crown.close();
    canvas.drawPath(crown, fill);

    // Kron üzerinde hafif gölge (hacim hissi)
    final grooveTop = crownTop + h * 0.05;
    final groove = Path()
      ..moveTo(cx, grooveTop)
      ..lineTo(cx, valleyY - h * 0.03);
    canvas.drawPath(
      groove,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = selected
            ? Colors.white.withValues(alpha: 0.5)
            : AppColors.toothShade,
    );
    // Sol yarıya hafif shade
    final shadePath = Path()
      ..moveTo(left + rTop, crownTop)
      ..lineTo(cx, crownTop)
      ..lineTo(cx, valleyY)
      ..quadraticBezierTo(
          (left + cx) / 2, crownBottom - h * 0.02, left, valleyY)
      ..close();
    canvas.drawPath(shadePath, shade);

    canvas.drawPath(crown, outline);
  }

  void _scallops(Path p, double left, double right, double valleyY,
      double bottom, int cusps) {
    final segW = (right - left) / cusps;
    for (int i = 0; i < cusps; i++) {
      final segRight = right - i * segW;
      final segLeft = right - (i + 1) * segW;
      final midX = (segRight + segLeft) / 2;
      p.quadraticBezierTo(midX, bottom + (bottom - valleyY) * 0.35, segLeft,
          valleyY);
    }
  }

  @override
  bool shouldRepaint(covariant _ToothPainter old) =>
      old.selected != selected || old.info.type != info.type;
}
