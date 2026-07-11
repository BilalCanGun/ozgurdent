import 'package:flutter/material.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../providers/clinic_provider.dart';
import 'dashboard_screen.dart';
import 'patients_screen.dart';
import 'statistics_screen.dart';

/// Uygulamanın ana kabuğu. Ekran genişliğine göre yan menü (tablet)
/// veya sabit (dock) yüzen alt menü (telefon) gösterir.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _destinations = [
    _NavItem('Panel', Icons.dashboard_rounded),
    _NavItem('Hastalar', Icons.people_alt_rounded),
    _NavItem('İstatistik', Icons.insert_chart_rounded),
  ];

  final _screens = const [
    DashboardScreen(),
    PatientsScreen(),
    StatisticsScreen(),
  ];

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicProvider>();
    if (!provider.isLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (Responsive.isWide(context)) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            _sideRail(),
            const VerticalDivider(width: 1),
            Expanded(child: SafeArea(child: IndexedStack(
              index: _index,
              children: _screens,
            ))),
          ],
        ),
      );
    }

    final barWidth =
        (MediaQuery.sizeOf(context).width - 28).clamp(0.0, 460.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: BottomBar(
        fit: StackFit.expand,
        hideOnScroll: false,
        showIcon: false,
        offset: 14,
        barAlignment: Alignment.bottomCenter,
        width: barWidth,
        borderRadius: BorderRadius.circular(22),
        barColor: AppColors.surface,
        barDecoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.14),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        body: (context, controller) => IndexedStack(
          index: _index,
          children: _screens,
        ),
        child: _barContent(),
      ),
    );
  }

  Widget _barContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (int i = 0; i < _destinations.length; i++)
            Expanded(child: _barItem(i)),
        ],
      ),
    );
  }

  Widget _barItem(int i) {
    final d = _destinations[i];
    final active = _index == i;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _select(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          gradient: active ? AppColors.primaryGradient : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              d.icon,
              size: 24,
              color: active ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(height: 3),
            Text(
              d.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sideRail() {
    return NavigationRail(
      selectedIndex: _index,
      onDestinationSelected: _select,
      extended: Responsive.isDesktop(context),
      minExtendedWidth: 210,
      backgroundColor: AppColors.surface,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 10),
        child: Image.asset(
          'assets/images/logo.png',
          height: Responsive.isDesktop(context) ? 46 : 34,
          fit: BoxFit.contain,
        ),
      ),
      destinations: [
        for (final d in _destinations)
          NavigationRailDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.icon),
            label: Text(d.label),
          ),
      ],
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  const _NavItem(this.label, this.icon);
}
