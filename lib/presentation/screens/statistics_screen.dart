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

    return SafeArea(
      child: Center(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
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
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                mainAxisExtent: 150,
              ),
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
              _pieCard(stats, breakdown),
              const SizedBox(height: 20),
              _paymentCard(stats),
              const SizedBox(height: 20),
              _breakdownCard(breakdown),
            ],
          ],
        ),
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

  // İşlem dilimleri için canlı renk paleti.
  static const List<Color> _sliceColors = [
    AppColors.primary,
    AppColors.accent,
    AppColors.success,
    AppColors.warning,
    AppColors.violet,
    AppColors.pink,
    AppColors.teal,
    AppColors.info,
    AppColors.danger,
    AppColors.amber,
  ];

  Widget _pieCard(
    PeriodStats stats,
    Map<String, ({int count, double total, double doctor})> breakdown,
  ) {
    // Yaptığın işlemleri, senin kazancına (doctor payı) göre büyükten küçüğe sırala.
    final entries = breakdown.entries
        .where((e) => e.value.doctor > 0)
        .toList()
      ..sort((a, b) => b.value.doctor.compareTo(a.value.doctor));

    final totalDoctor = entries.fold<double>(0, (s, e) => s + e.value.doctor);

    final sections = <PieChartSectionData>[
      for (int i = 0; i < entries.length; i++)
        PieChartSectionData(
          value: entries[i].value.doctor,
          color: _sliceColors[i % _sliceColors.length],
          radius: 32,
          showTitle: false,
        ),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kazanç Dağılımı (İşlemlere Göre)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Toplam senin kazancın ve yaptığın işlemlerin dağılımı',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 210,
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 62,
                        startDegreeOffset: -90,
                        sections: sections.isEmpty
                            ? [
                                PieChartSectionData(
                                  value: 1,
                                  color: AppColors.border,
                                  radius: 32,
                                  showTitle: false,
                                )
                              ]
                            : sections,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          Fmt.money(stats.doctor),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        const Text(
                          'Senin Kazancın',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${stats.procedureCount} işlem',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < entries.length; i++)
            _procedureLegendRow(
              _sliceColors[i % _sliceColors.length],
              entries[i].key,
              entries[i].value.doctor,
              entries[i].value.count,
              totalDoctor <= 0 ? 0 : entries[i].value.doctor / totalDoctor * 100,
            ),
        ],
      ),
    );
  }

  Widget _procedureLegendRow(
      Color color, String name, double doctor, int count, double pct) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            '%${pct.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            Fmt.money(doctor),
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
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
