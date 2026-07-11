import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../providers/clinic_provider.dart';
import '../widgets/app_card.dart';
import '../widgets/common_bits.dart';
import '../widgets/empty_state.dart';
import '../widgets/stat_tile.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  StatsRange _range = StatsRange.month;
  DateTime _ref = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicProvider>();
    final stats = provider.statsFor(_ref, _range);
    final breakdown = provider.breakdownByProcedure(_ref, _range);
    final cols = Responsive.gridColumns(context).clamp(2, 4);

    return Center(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          children: [
            const PageHeader(
              title: 'İstatistik',
              subtitle: 'Kazanç ve işlem özeti',
            ),
            const SizedBox(height: 16),
            _rangeSelector(),
            const SizedBox(height: 12),
            _periodNavigator(),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.15,
              children: [
                StatTile(
                  label: 'Toplam Ciro',
                  value: Fmt.money(stats.total),
                  icon: Icons.summarize_outlined,
                  color: AppColors.textPrimary,
                ),
                StatTile(
                  label: 'Sana Kalan',
                  value: Fmt.money(stats.doctor),
                  icon: Icons.account_balance_wallet_outlined,
                  color: AppColors.doctorShare,
                ),
                StatTile(
                  label: 'Kliniğe Kalan',
                  value: Fmt.money(stats.clinic),
                  icon: Icons.business_outlined,
                  color: AppColors.clinicShare,
                ),
                StatTile(
                  label: 'İşlem Sayısı',
                  value: '${stats.procedureCount}',
                  icon: Icons.medical_services_outlined,
                  color: AppColors.accent,
                  subtitle: '${stats.patientCount} hasta',
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (stats.total <= 0)
              const AppCard(
                child: EmptyState(
                  icon: Icons.pie_chart_outline,
                  title: 'Bu dönemde veri yok',
                  message: 'Seçilen tarih aralığında kayıtlı işlem bulunmuyor.',
                ),
              )
            else ...[
              _pieCard(stats),
              const SizedBox(height: 20),
              _paymentCard(stats),
              const SizedBox(height: 20),
              _breakdownCard(breakdown),
            ],
          ],
        ),
      ),
    );
  }

  Widget _rangeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _rangeTab('Günlük', StatsRange.day),
          _rangeTab('Aylık', StatsRange.month),
          _rangeTab('Yıllık', StatsRange.year),
        ],
      ),
    );
  }

  Widget _rangeTab(String label, StatsRange range) {
    final active = _range == range;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _range = range),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
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

  Widget _periodNavigator() {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _shift(-1),
          ),
          Expanded(
            child: Center(
              child: Text(
                _periodLabel(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _canGoForward() ? () => _shift(1) : null,
          ),
        ],
      ),
    );
  }

  String _periodLabel() {
    switch (_range) {
      case StatsRange.day:
        return '${Fmt.weekday(_ref)}, ${Fmt.date(_ref)}';
      case StatsRange.month:
        return Fmt.monthYear(_ref);
      case StatsRange.year:
        return '${_ref.year}';
    }
  }

  bool _canGoForward() {
    final now = DateTime.now();
    switch (_range) {
      case StatsRange.day:
        return DateTime(_ref.year, _ref.month, _ref.day)
            .isBefore(DateTime(now.year, now.month, now.day));
      case StatsRange.month:
        return DateTime(_ref.year, _ref.month)
            .isBefore(DateTime(now.year, now.month));
      case StatsRange.year:
        return _ref.year < now.year;
    }
  }

  void _shift(int dir) {
    setState(() {
      switch (_range) {
        case StatsRange.day:
          _ref = _ref.add(Duration(days: dir));
          break;
        case StatsRange.month:
          _ref = DateTime(_ref.year, _ref.month + dir, 1);
          break;
        case StatsRange.year:
          _ref = DateTime(_ref.year + dir, _ref.month, 1);
          break;
      }
    });
  }

  Widget _pieCard(PeriodStats stats) {
    final total = stats.total <= 0 ? 1 : stats.total;
    final doctorPct = stats.doctor / total * 100;
    final clinicPct = stats.clinic / total * 100;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gelir Dağılımı',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 52,
                          startDegreeOffset: -90,
                          sections: [
                            PieChartSectionData(
                              value: stats.doctor,
                              color: AppColors.doctorShare,
                              radius: 30,
                              showTitle: false,
                            ),
                            PieChartSectionData(
                              value: stats.clinic,
                              color: AppColors.clinicShare,
                              radius: 30,
                              showTitle: false,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            Fmt.money(stats.total),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Text(
                            'Toplam',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _legend(
                        AppColors.doctorShare,
                        'Sana Kalan',
                        Fmt.money(stats.doctor),
                        doctorPct,
                      ),
                      const SizedBox(height: 16),
                      _legend(
                        AppColors.clinicShare,
                        'Kliniğe Kalan',
                        Fmt.money(stats.clinic),
                        clinicPct,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label, String value, double pct) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          '%${pct.toStringAsFixed(1)}',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _paymentCard(PeriodStats stats) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: _paymentBox(
              'Tahsil Edilen',
              Fmt.money(stats.paid),
              AppColors.success,
              Icons.check_circle_outline,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _paymentBox(
              'Bekleyen',
              Fmt.money(stats.unpaid),
              AppColors.warning,
              Icons.schedule,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentBox(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _breakdownCard(
      Map<String, ({int count, double total, double doctor})> breakdown) {
    final entries = breakdown.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'İşlem Kırılımı',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          for (final e in entries) ...[
            const Divider(height: 20),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${e.value.count}x',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    e.key,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Fmt.money(e.value.total),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Sana ${Fmt.money(e.value.doctor)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
