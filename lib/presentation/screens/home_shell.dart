import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../providers/clinic_provider.dart';
import 'dashboard_screen.dart';
import 'patients_screen.dart';
import 'statistics_screen.dart';

/// Uygulamanın ana kabuğu. Ekran genişliğine göre yan menü (tablet)
/// veya alt menü (telefon) gösterir.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _destinations = [
    _NavItem('Panel', Icons.dashboard_outlined, Icons.dashboard),
    _NavItem('Hastalar', Icons.people_outline, Icons.people),
    _NavItem('İstatistik', Icons.bar_chart_outlined, Icons.bar_chart),
  ];

  final _screens = const [
    DashboardScreen(),
    PatientsScreen(),
    StatisticsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicProvider>();
    if (!provider.isLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final wide = Responsive.isWide(context);
    final body = _screens[_index];

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            _sideRail(),
            const VerticalDivider(width: 1),
            Expanded(child: SafeArea(child: body)),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.activeIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }

  Widget _sideRail() {
    return NavigationRail(
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      extended: Responsive.isDesktop(context),
      minExtendedWidth: 210,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.medical_services,
                  color: Colors.white, size: 22),
            ),
            if (Responsive.isDesktop(context)) ...[
              const SizedBox(width: 10),
              const Text(
                'ÖzgürDent',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ],
        ),
      ),
      destinations: [
        for (final d in _destinations)
          NavigationRailDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.activeIcon),
            label: Text(d.label),
          ),
      ],
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _NavItem(this.label, this.icon, this.activeIcon);
}
