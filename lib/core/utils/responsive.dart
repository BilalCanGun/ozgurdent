import 'package:flutter/widgets.dart';

/// Ekran genişliğine göre yerleşim kararları için basit yardımcı.
class Responsive {
  Responsive._();

  static const double tabletBreakpoint = 720;
  static const double desktopBreakpoint = 1100;

  static bool isPhone(BuildContext c) =>
      MediaQuery.sizeOf(c).width < tabletBreakpoint;

  static bool isTablet(BuildContext c) {
    final w = MediaQuery.sizeOf(c).width;
    return w >= tabletBreakpoint && w < desktopBreakpoint;
  }

  static bool isWide(BuildContext c) =>
      MediaQuery.sizeOf(c).width >= tabletBreakpoint;

  static bool isDesktop(BuildContext c) =>
      MediaQuery.sizeOf(c).width >= desktopBreakpoint;

  /// Izgara (grid) için sütun sayısı.
  static int gridColumns(BuildContext c) {
    final w = MediaQuery.sizeOf(c).width;
    if (w >= desktopBreakpoint) return 4;
    if (w >= tabletBreakpoint) return 3;
    if (w >= 480) return 2;
    return 1;
  }

  /// İçeriğin ortada kalması için maksimum genişlik.
  static double contentMaxWidth(BuildContext c) =>
      isDesktop(c) ? 1200 : double.infinity;
}
