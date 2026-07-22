import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../data/local/export_service.dart';
import '../../data/models/treatment.dart';
import '../providers/clinic_provider.dart';
import '../providers/theme_controller.dart';
import '../widgets/app_card.dart';

/// Filtreli, detaylı Excel raporu üretme ekranı.
///
/// Kullanıcı tarih aralığı, işlem türü ve tahsilat durumuna göre filtreler,
/// canlı özeti görür ve seçili kayıtları Excel olarak dışa aktarır.
class ReportExportScreen extends StatefulWidget {
  const ReportExportScreen({super.key});

  @override
  State<ReportExportScreen> createState() => _ReportExportScreenState();
}

class _ReportExportScreenState extends State<ReportExportScreen> {
  DateTime? _start;
  DateTime? _end;
  final Set<String> _procedures = {};
  final Set<PaymentStage> _stages = {};
  String _query = '';
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
    final provider = context.watch<ClinicProvider>();
    final filtered = _filter(provider.treatments);

    double total = 0, doctor = 0, collected = 0, outstanding = 0;
    for (final t in filtered) {
      total += t.totalPrice;
      doctor += t.doctorShare;
      collected += t.collectedAmount;
      outstanding += t.remaining;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Detaylı Excel Raporu')),
      bottomNavigationBar: _exportBar(context, provider, filtered),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              children: [
                Text(
                  'İstediğin filtreleri seç, kendi raporunu çıkar. '
                  'Filtre seçmezsen tüm kayıtlar aktarılır.',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 18),
                _sectionLabel('Tarih Aralığı'),
                const SizedBox(height: 10),
                _dateRangeCard(),
                const SizedBox(height: 10),
                _datePresets(),
                const SizedBox(height: 22),
                _sectionLabel('İşlem Türü'),
                const SizedBox(height: 10),
                _procedureFilter(provider),
                const SizedBox(height: 22),
                _sectionLabel('Tahsilat Durumu'),
                const SizedBox(height: 10),
                _stageFilter(),
                const SizedBox(height: 22),
                _sectionLabel('Hasta'),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'İsim veya telefona göre filtrele...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 24),
                _summaryCard(filtered.length, total, doctor, collected,
                    outstanding),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FİLTRELEME
  // ---------------------------------------------------------------------------
  List<Treatment> _filter(List<Treatment> treatments) {
    final q = _query.toLowerCase().trim();
    final provider = context.read<ClinicProvider>();
    DateTime? startDay =
        _start == null ? null : DateTime(_start!.year, _start!.month, _start!.day);
    DateTime? endDay =
        _end == null ? null : DateTime(_end!.year, _end!.month, _end!.day);

    return treatments.where((t) {
      final d = DateTime(t.appointmentDate.year, t.appointmentDate.month,
          t.appointmentDate.day);
      if (startDay != null && d.isBefore(startDay)) return false;
      if (endDay != null && d.isAfter(endDay)) return false;
      if (_procedures.isNotEmpty && !_procedures.contains(t.procedureName)) {
        return false;
      }
      if (_stages.isNotEmpty && !_stages.contains(t.stage)) return false;
      if (q.isNotEmpty) {
        final p = provider.patientById(t.patientId);
        final name = p?.name.toLowerCase() ?? '';
        final phone = p?.phone ?? '';
        if (!name.contains(q) && !phone.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // TARİH
  // ---------------------------------------------------------------------------
  Widget _dateRangeCard() {
    return Row(
      children: [
        Expanded(
          child: _dateField(
            label: 'Başlangıç',
            value: _start == null ? 'Tümü' : Fmt.date(_start!),
            onTap: () => _pickDate(isStart: true),
            onClear: _start == null ? null : () => setState(() => _start = null),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _dateField(
            label: 'Bitiş',
            value: _end == null ? 'Tümü' : Fmt.date(_end!),
            onTap: () => _pickDate(isStart: false),
            onClear: _end == null ? null : () => setState(() => _end = null),
          ),
        ),
      ],
    );
  }

  Widget _dateField({
    required String label,
    required String value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(Icons.event, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (onClear != null)
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close, size: 18, color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _start : _end) ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      locale: const Locale('tr', 'TR'),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
        if (_end != null && _end!.isBefore(picked)) _end = picked;
      } else {
        _end = picked;
        if (_start != null && _start!.isAfter(picked)) _start = picked;
      }
    });
  }

  Widget _datePresets() {
    final now = DateTime.now();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _presetChip('Tümü', () => setState(() {
              _start = null;
              _end = null;
            })),
        _presetChip('Bu ay', () => setState(() {
              _start = DateTime(now.year, now.month, 1);
              _end = DateTime(now.year, now.month + 1, 0);
            })),
        _presetChip('Geçen ay', () => setState(() {
              _start = DateTime(now.year, now.month - 1, 1);
              _end = DateTime(now.year, now.month, 0);
            })),
        _presetChip('Bu yıl', () => setState(() {
              _start = DateTime(now.year, 1, 1);
              _end = DateTime(now.year, 12, 31);
            })),
        _presetChip('Son 30 gün', () => setState(() {
              _end = now;
              _start = now.subtract(const Duration(days: 30));
            })),
      ],
    );
  }

  Widget _presetChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: AppColors.surfaceAlt,
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.border),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // İŞLEM TÜRÜ
  // ---------------------------------------------------------------------------
  Widget _procedureFilter(ClinicProvider provider) {
    // Kayıtlarda geçen benzersiz işlem adları.
    final names = <String>{for (final t in provider.treatments) t.procedureName}
        .toList()
      ..sort();
    if (names.isEmpty) {
      return Text('Kayıt yok.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final n in names)
          _filterChip(
            label: n,
            selected: _procedures.contains(n),
            onTap: () => setState(() {
              if (!_procedures.add(n)) _procedures.remove(n);
            }),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TAHSİLAT DURUMU
  // ---------------------------------------------------------------------------
  Widget _stageFilter() {
    const items = [
      (PaymentStage.pending, 'Bekliyor'),
      (PaymentStage.partial, 'Kısmi'),
      (PaymentStage.clinicCollected, 'Payın bekliyor'),
      (PaymentStage.settled, 'Tamamlandı'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final it in items)
          _filterChip(
            label: it.$2,
            selected: _stages.contains(it.$1),
            onTap: () => setState(() {
              if (!_stages.add(it.$1)) _stages.remove(it.$1);
            }),
          ),
      ],
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check, size: 15, color: AppColors.primary),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ÖZET
  // ---------------------------------------------------------------------------
  Widget _summaryCard(int count, double total, double doctor, double collected,
      double outstanding) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_alt_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Filtre Sonucu',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '$count işlem',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _summaryBox('Toplam Ciro', total, AppColors.textPrimary)),
              const SizedBox(width: 10),
              Expanded(child: _summaryBox('Sana Kalan', doctor, AppColors.doctorShare)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _summaryBox('Tahsil Edilen', collected, AppColors.success)),
              const SizedBox(width: 10),
              Expanded(child: _summaryBox('Bekleyen', outstanding, AppColors.warning)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryBox(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Fmt.money(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(label,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _sectionLabel(String s) => Text(
        s,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      );

  // ---------------------------------------------------------------------------
  // DIŞA AKTARMA
  // ---------------------------------------------------------------------------
  Widget _exportBar(
      BuildContext context, ClinicProvider provider, List<Treatment> filtered) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: (_busy || filtered.isEmpty)
                ? null
                : () => _export(context, provider, filtered),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: Colors.white),
                  )
                : const Icon(Icons.download),
            label: Text(filtered.isEmpty
                ? 'Filtreye uyan kayıt yok'
                : '${filtered.length} kaydı Excel çıkar'),
          ),
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context, ClinicProvider provider,
      List<Treatment> filtered) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    try {
      await ExportService.exportDetailed(
        treatments: filtered,
        patients: provider.patients,
        sharePositionOrigin: origin,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Dışa aktarma başarısız: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
