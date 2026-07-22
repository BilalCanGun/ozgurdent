import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/procedure_catalog.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/pickers.dart';
import '../../data/local/photo_storage.dart';
import '../../data/models/procedure_type.dart';
import '../../data/models/treatment.dart';
import '../providers/clinic_provider.dart';
import '../providers/theme_controller.dart';
import '../widgets/app_card.dart';
import '../widgets/tooth_chart.dart';
import 'photo_viewer_screen.dart';

enum _CollectMode { pending, partial, full }

/// Tahsilat giriş biçimi: hızlı "tamamı tahsil edildi" veya detaylı seçim.
enum _PayTab { full, detailed }

/// Formdaki tek bir işlem satırının düzenlenebilir durumu.
class _Entry {
  ProcedureType procedure;
  Set<String> teeth = {};
  final priceCtrl = TextEditingController();
  final labFeeCtrl = TextEditingController();
  final manualNameCtrl = TextEditingController();
  final manualPctCtrl = TextEditingController(text: '30');
  final noteCtrl = TextEditingController();
  final collectedCtrl = TextEditingController();
  final cardPctCtrl = TextEditingController();
  bool cardOn = false;
  _PayTab payTab = _PayTab.full;
  _CollectMode collectMode = _CollectMode.pending;
  int installments = 1;
  bool doctorPaid = false;
  List<String> photos = [];

  /// Düzenleme açılışında kaydın sahip olduğu fotoğraflar (kaydedince
  /// çıkarılanları diskten silmek için).
  List<String> originalPhotos = [];

  /// Bu oturumda çekilen/eklenen fotoğraflar (kaydedilmeden çıkılırsa
  /// öksüz kalmasınlar diye temizlenir).
  final Set<String> captured = {};

  String? existingId;
  DateTime? createdAt;

  _Entry(this.procedure);

  void dispose() {
    priceCtrl.dispose();
    labFeeCtrl.dispose();
    manualNameCtrl.dispose();
    manualPctCtrl.dispose();
    noteCtrl.dispose();
    collectedCtrl.dispose();
    cardPctCtrl.dispose();
  }
}

/// İşlem (ve aynı zamanda randevu) ekleme / düzenleme ekranı.
/// Ekleme modunda aynı randevuya birden fazla işlem eklenebilir.
class TreatmentFormScreen extends StatefulWidget {
  final String patientId;
  final String? treatmentId;

  /// Takvimde bir saate dokunularak açıldıysa, randevu tarih+saati önceden
  /// bu değere ayarlanır (yeni işlem modunda).
  final DateTime? initialDate;

  const TreatmentFormScreen({
    super.key,
    required this.patientId,
    this.treatmentId,
    this.initialDate,
  });

  @override
  State<TreatmentFormScreen> createState() => _TreatmentFormScreenState();
}

class _TreatmentFormScreenState extends State<TreatmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<_Entry> _entries = [];

  DateTime _date = DateTime.now();
  Treatment? _editing;
  bool _saved = false;

  bool get _isEdit => widget.treatmentId != null;

  /// Katalogda olmayan bir işlem için, kaydın snapshot'ından tanım üretir.
  ProcedureType _procFromTreatment(Treatment t) => ProcedureType(
        id: t.procedureId,
        name: t.procedureName,
        model: t.model,
        percentage: t.percentage,
        netAmount: t.netAmount,
        requiresLabFee: t.labFee > 0,
      );

  List<ProcedureType> get _catalog {
    final list = context.read<ClinicProvider>().procedures;
    return list.isEmpty ? ProcedureCatalog.all : list;
  }

  @override
  void initState() {
    super.initState();
    final provider = context.read<ClinicProvider>();

    if (_isEdit) {
      _editing = provider.treatments
          .where((t) => t.id == widget.treatmentId)
          .cast<Treatment?>()
          .firstWhere((t) => true, orElse: () => null);
      final t = _editing;
      // Katalogda bulunamayan (silinmiş özel) işlemde, kaydın kendi
      // snapshot'ından işlem tanımı yeniden kurulur (ad/kural korunur).
      final proc = t == null
          ? ProcedureCatalog.manual
          : (provider.procedureById(t.procedureId) ?? _procFromTreatment(t));
      final e = _Entry(proc);
      if (t != null) {
        e.existingId = t.id;
        e.createdAt = t.createdAt;
        if (t.procedureId == ProcedureCatalog.manual.id) {
          e.manualNameCtrl.text = t.procedureName;
          e.manualPctCtrl.text = (t.percentage * 100).toStringAsFixed(0);
        }
        e.teeth = t.teeth.toSet();
        e.priceCtrl.text = _trimNum(t.totalPrice);
        e.labFeeCtrl.text = t.labFee > 0 ? _trimNum(t.labFee) : '';
        e.noteCtrl.text = t.note;
        e.installments = t.installmentCount;
        e.doctorPaid = t.doctorPaid;
        if (t.cardCommissionRate > 0) {
          e.cardOn = true;
          e.cardPctCtrl.text = _trimNum(t.cardCommissionRate * 100);
        }
        e.photos = [...t.photos];
        e.originalPhotos = [...t.photos];
        if (t.clinicCollected) {
          e.collectMode = _CollectMode.full;
          e.payTab = _PayTab.full;
        } else if (t.partiallyCollected) {
          e.collectMode = _CollectMode.partial;
          e.collectedCtrl.text = _trimNum(t.collectedAmount);
          e.payTab = _PayTab.detailed;
        } else {
          e.collectMode = _CollectMode.pending;
          e.payTab = _PayTab.detailed;
        }
        _date = t.appointmentDate;
      }
      _entries.add(e);
    } else {
      if (widget.initialDate != null) _date = widget.initialDate!;
      _entries.add(_Entry(_catalog.first));
    }
  }

  @override
  void dispose() {
    // Kaydedilmeden çıkıldıysa, bu oturumda çekilen yeni fotoğraflar
    // hiçbir kayda bağlı değildir → diskten temizle (öksüz dosya bırakma).
    if (!_saved) {
      for (final e in _entries) {
        for (final path in e.captured) {
          PhotoStorage.delete(path);
        }
      }
    }
    for (final e in _entries) {
      e.dispose();
    }
    super.dispose();
  }

  String _trimNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  double _priceOf(_Entry e) =>
      double.tryParse(e.priceCtrl.text.replaceAll(',', '.')) ?? 0;
  double _labFeeOf(_Entry e) =>
      double.tryParse(e.labFeeCtrl.text.replaceAll(',', '.')) ?? 0;
  double _manualPctOf(_Entry e) =>
      (double.tryParse(e.manualPctCtrl.text.replaceAll(',', '.')) ?? 0) / 100;

  bool _isManual(_Entry e) => e.procedure.id == ProcedureCatalog.manual.id;

  /// Kredi kartı komisyon oranı (0-1). Kapalıysa 0.
  double _cardRateOf(_Entry e) {
    if (!e.cardOn) return 0;
    final pct =
        (double.tryParse(e.cardPctCtrl.text.replaceAll(',', '.')) ?? 0) / 100;
    return pct.clamp(0, 1).toDouble();
  }

  double _cardAmountOf(_Entry e) => _priceOf(e) * _cardRateOf(e);

  PaymentShares _sharesOf(_Entry e) => e.procedure.computeShares(
        totalPrice: _priceOf(e),
        labFee: _labFeeOf(e),
        cardCommission: _cardAmountOf(e),
        overridePercentage: _isManual(e) ? _manualPctOf(e) : null,
      );

  double _collectedOf(_Entry e) {
    if (e.payTab == _PayTab.full) return _priceOf(e);
    switch (e.collectMode) {
      case _CollectMode.pending:
        return 0;
      case _CollectMode.full:
        return _priceOf(e);
      case _CollectMode.partial:
        final v =
            double.tryParse(e.collectedCtrl.text.replaceAll(',', '.')) ?? 0;
        return v.clamp(0, _priceOf(e)).toDouble();
    }
  }

  double get _totalDoctor =>
      _entries.fold(0.0, (s, e) => s + _sharesOf(e).doctor);

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'İşlemi Düzenle' : 'Yeni İşlem'),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: 'Sil',
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      bottomNavigationBar: _bottomBar(),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                children: [
                  _sectionTitle('Randevu Tarihi'),
                  const SizedBox(height: 10),
                  _dateTimePickers(),
                  const SizedBox(height: 24),
                  for (int i = 0; i < _entries.length; i++) ...[
                    _entryCard(i),
                    const SizedBox(height: 16),
                  ],
                  if (!_isEdit)
                    OutlinedButton.icon(
                      onPressed: _addEntry,
                      icon: const Icon(Icons.add),
                      label: const Text('Başka işlem ekle'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _addEntry() {
    setState(() => _entries.add(_Entry(_catalog.first)));
  }

  void _removeEntry(int i) {
    setState(() {
      _entries[i].dispose();
      _entries.removeAt(i);
    });
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      );

  // ---------------------------------------------------------------------------
  // İŞLEM KARTI
  // ---------------------------------------------------------------------------
  Widget _entryCard(int i) {
    final e = _entries[i];
    final shares = _sharesOf(e);
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'İşlem ${i + 1}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (_entries.length > 1)
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => _removeEntry(i),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _procedurePicker(e),
          if (_isManual(e)) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: e.manualNameCtrl,
                    decoration: const InputDecoration(labelText: 'İşlem adı'),
                    validator: (v) => _isManual(e) &&
                            (v == null || v.trim().isEmpty)
                        ? 'Gerekli'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: e.manualPctCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Yüzde',
                      suffixText: '%',
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _teethInline(e),
          const SizedBox(height: 16),
          TextFormField(
            controller: e.priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
            ],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Hastadan alınan toplam ücret *',
              prefixIcon: Icon(Icons.payments_outlined),
              suffixText: '₺',
            ),
            validator: (v) {
              final val = double.tryParse((v ?? '').replaceAll(',', '.')) ?? 0;
              return val <= 0 ? 'Geçerli bir ücret gir' : null;
            },
          ),
          if (e.procedure.requiresLabFee) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: e.labFeeCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
              ],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Teknisyen / laboratuvar bedeli',
                prefixIcon: Icon(Icons.biotech_outlined),
                suffixText: '₺',
              ),
            ),
          ],
          const SizedBox(height: 14),
          _cardCommissionSection(e),
          const SizedBox(height: 14),
          _sharePreview(shares),
          const SizedBox(height: 16),
          _paymentSection(e),
          const SizedBox(height: 12),
          _photoSection(e),
          const SizedBox(height: 12),
          TextFormField(
            controller: e.noteCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'İşlem notu (opsiyonel)',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _teethInline(_Entry e) {
    final count = e.teeth.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.medical_information_outlined,
                color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              'Diş Seçimi',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            if (count > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count diş',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          // Diş şemasına kart içindeki tüm genişliği ver: yatay iç padding yok.
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
          ),
          child: ToothChart(
            selected: e.teeth,
            onChanged: (s) => setState(() => e.teeth = s),
          ),
        ),
      ],
    );
  }

  Widget _procedurePicker(_Entry e) {
    return AppCard(
      color: AppColors.surfaceAlt,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      onTap: () => _openProcedureSheet(e),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.medical_services_outlined,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isManual(e) && e.manualNameCtrl.text.isNotEmpty
                      ? e.manualNameCtrl.text
                      : e.procedure.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  _pricingRuleText(e.procedure),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.expand_more, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  String _pricingRuleText(ProcedureType p) {
    switch (p.model) {
      case PricingModel.percentage:
        if (p.isCustom) return 'Manuel yüzde belirlersin';
        return 'Sana ${Fmt.percent(p.percentage)}, kalanı kliniğe';
      case PricingModel.net:
        return 'Sana net ${Fmt.money(p.netAmount)}, kalanı kliniğe';
      case PricingModel.percentageAfterLab:
        return 'Teknisyen düşülür, kalanın ${Fmt.percent(p.percentage)}\'i sana';
    }
  }

  Future<void> _openProcedureSheet(_Entry e) async {
    final items = [..._catalog, ProcedureCatalog.manual];
    final selected = await showModalBottomSheet<ProcedureType>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.92,
          builder: (_, controller) => Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'İşlem Seç',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, idx) {
                    final p = items[idx];
                    final active = p.id == e.procedure.id;
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(ctx, p),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.surfaceAlt
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                active ? AppColors.primary : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              p.isCustom
                                  ? Icons.tune
                                  : Icons.medical_services_outlined,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    _pricingRuleText(p),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (active)
                              Icon(Icons.check_circle,
                                  color: AppColors.primary),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      setState(() {
        e.procedure = selected;
        if (!selected.requiresLabFee) e.labFeeCtrl.clear();
        // Varsayılan ücret varsa ve alan boşsa ön-doldur.
        if (selected.defaultPrice > 0 && e.priceCtrl.text.trim().isEmpty) {
          e.priceCtrl.text = _trimNum(selected.defaultPrice);
        }
      });
    }
  }

  // ---------------------------------------------------------------------------
  // KREDİ KARTI KOMİSYONU (işlem başına, seçili modelle birlikte çalışır)
  // ---------------------------------------------------------------------------
  Widget _cardCommissionSection(_Entry e) {
    final amount = _cardAmountOf(e);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.credit_card, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kredi kartı komisyonu',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Switch(
                value: e.cardOn,
                activeColor: AppColors.primary,
                onChanged: (v) => setState(() => e.cardOn = v),
              ),
            ],
          ),
          if (e.cardOn) ...[
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: e.cardPctCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Komisyon oranı',
                      prefixIcon: Icon(Icons.percent),
                      suffixText: '%',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Düşülecek',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '−${Fmt.money(amount)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.danger,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Komisyon önce toplamdan düşülür, kalan tutar paya bölünür.',
              style:
                  TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sharePreview(PaymentShares shares) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _shareBox('Sana Kalan', shares.doctor, AppColors.doctorShare,
                Icons.account_balance_wallet_outlined),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _shareBox('Kliniğe Kalan', shares.clinic,
                AppColors.clinicShare, Icons.business_outlined),
          ),
        ],
      ),
    );
  }

  Widget _shareBox(String label, double value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            Fmt.money(value),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ÖDEME / TAHSİLAT (işlem başına)
  // ---------------------------------------------------------------------------
  Widget _paymentSection(_Entry e) {
    final clinicCollected = _collectedOf(e) >= _priceOf(e) - 0.005 &&
        _priceOf(e) > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tahsilat',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        // Üst seçim: hızlı "Tamamı tahsil edildi" veya "Detaylı".
        Row(
          children: [
            _payTabSeg(e, 'Tamamı tahsil edildi', _PayTab.full,
                Icons.check_circle),
            _payTabSeg(e, 'Detaylı', _PayTab.detailed, Icons.tune),
          ],
        ),
        const SizedBox(height: 12),
        if (e.payTab == _PayTab.full)
          _fullShareChoice(e)
        else
          _detailedCollect(e, clinicCollected),
      ],
    );
  }

  /// "Tamamı tahsil edildi" seçildiğinde payın kimde olduğunu seçtirir.
  Widget _fullShareChoice(_Entry e) {
    Widget opt(String label, String sub, bool paid, IconData icon, Color c) {
      final active = e.doctorPaid == paid;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => e.doctorPaid = paid),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: active ? c.withValues(alpha: 0.14) : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? c : Colors.transparent,
                width: 1.3,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon,
                    size: 18, color: active ? c : AppColors.textSecondary),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: active ? c : AppColors.textPrimary,
                  ),
                ),
                Text(
                  sub,
                  style:
                      TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        opt('Payımı aldım', 'Tamamen kapandı', true, Icons.verified,
            AppColors.success),
        opt('Kliniğin payında', 'Payım bekliyor', false,
            Icons.account_balance_wallet_outlined, AppColors.violet),
      ],
    );
  }

  /// Detaylı tahsilat: bekliyor / kısmi / tamamı + taksit + doktor payı.
  Widget _detailedCollect(_Entry e, bool clinicCollected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _collectSeg(e, 'Bekliyor', _CollectMode.pending,
                Icons.schedule, AppColors.warning),
            _collectSeg(e, 'Kısmi', _CollectMode.partial,
                Icons.timelapse, AppColors.info),
            _collectSeg(e, 'Tamamı', _CollectMode.full,
                Icons.check_circle, AppColors.success),
          ],
        ),
        if (e.collectMode == _CollectMode.partial) ...[
          const SizedBox(height: 10),
          TextFormField(
            controller: e.collectedCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
            ],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Tahsil edilen tutar',
              prefixIcon: Icon(Icons.payments_outlined),
              suffixText: '₺',
            ),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _installmentStepper(e)),
            const SizedBox(width: 10),
            Expanded(child: _doctorPaidChip(e, clinicCollected)),
          ],
        ),
      ],
    );
  }

  Widget _payTabSeg(_Entry e, String label, _PayTab tab, IconData icon) {
    final active = e.payTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => e.payTab = tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          decoration: BoxDecoration(
            gradient: active ? AppColors.primaryGradient : null,
            color: active ? null : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: active ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _collectSeg(
      _Entry e, String label, _CollectMode m, IconData icon, Color color) {
    final active = e.collectMode == m;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => e.collectMode = m),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color:
                active ? color.withValues(alpha: 0.14) : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? color : Colors.transparent,
              width: 1.3,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 18, color: active ? color : AppColors.textSecondary),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active ? color : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _installmentStepper(_Entry e) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: e.installments > 1
                ? () => setState(() => e.installments--)
                : null,
            icon: const Icon(Icons.remove, size: 18),
          ),
          Expanded(
            child: Center(
              child: Text(
                e.installments == 1 ? 'Peşin' : '${e.installments}x',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: e.installments < 12
                ? () => setState(() => e.installments++)
                : null,
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _doctorPaidChip(_Entry e, bool clinicCollected) {
    final on = e.doctorPaid && clinicCollected;
    return GestureDetector(
      onTap: clinicCollected
          ? () => setState(() => e.doctorPaid = !e.doctorPaid)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: on
              ? AppColors.success.withValues(alpha: 0.14)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: on ? AppColors.success : Colors.transparent,
            width: 1.3,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              on ? Icons.verified : Icons.account_balance_wallet_outlined,
              size: 16,
              color: clinicCollected
                  ? (on ? AppColors.success : AppColors.violet)
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Payı aldım',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: clinicCollected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FOTOĞRAFLAR (işlem başına)
  // ---------------------------------------------------------------------------
  Widget _photoSection(_Entry e) {
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _addPhotoTile(e),
          for (int i = 0; i < e.photos.length; i++) _photoThumb(e, i),
        ],
      ),
    );
  }

  Widget _addPhotoTile(_Entry e) {
    return GestureDetector(
      onTap: () => _pickPhotoSource(e),
      child: Container(
        width: 84,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined,
                color: AppColors.primary, size: 26),
            const SizedBox(height: 4),
            Text(
              'Fotoğraf',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoThumb(_Entry e, int i) {
    return GestureDetector(
      onTap: () => _openViewer(e, i),
      child: Container(
        width: 84,
        margin: const EdgeInsets.only(right: 10),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(e.photos[i]), fit: BoxFit.cover),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _removePhoto(e, i),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close,
                      color: Colors.white, size: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openViewer(_Entry e, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoViewerScreen(
          photos: e.photos,
          initialIndex: index,
          onDelete: (i) => _removePhoto(e, i),
        ),
      ),
    );
  }

  Future<void> _pickPhotoSource(_Entry e) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading:
                  Icon(Icons.photo_camera_outlined, color: AppColors.primary),
              title: const Text('Kamera ile çek'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading:
                  Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: const Text('Galeriden seç'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final path = await PhotoStorage.capture(source);
      if (path != null) {
        setState(() {
          e.photos.add(path);
          e.captured.add(path);
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotoğraf eklenemedi.')),
        );
      }
    }
  }

  /// Listeden çıkarır; disk dosyası ancak kaydetme anında silinir
  /// (kaydetmeden çıkılırsa kırık referans / veri kaybı olmaz).
  void _removePhoto(_Entry e, int i) {
    if (i < 0 || i >= e.photos.length) return;
    setState(() => e.photos.removeAt(i));
  }

  // ---------------------------------------------------------------------------
  // TARİH / SAAT
  // ---------------------------------------------------------------------------
  Widget _dateTimePickers() {
    return Row(
      children: [
        Expanded(
          child: _pickerField(
            icon: Icons.event,
            label: 'Tarih',
            value: Fmt.date(_date),
            onTap: _pickDate,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _pickerField(
            icon: Icons.access_time,
            label: 'Saat',
            value: Fmt.time(_date),
            onTap: _pickTime,
          ),
        ),
      ],
    );
  }

  Widget _pickerField({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      locale: const Locale('tr', 'TR'),
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(
            picked.year, picked.month, picked.day, _date.hour, _date.minute);
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await pickTime(context, TimeOfDay.fromDateTime(_date));
    if (picked != null) {
      setState(() {
        _date = DateTime(
            _date.year, _date.month, _date.day, picked.hour, picked.minute);
      });
    }
  }

  // ---------------------------------------------------------------------------
  // KAYDET
  // ---------------------------------------------------------------------------
  Widget _bottomBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Toplam sana kalan',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                Text(
                  Fmt.money(_totalDoctor),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: Text(_isEdit
                    ? 'Güncelle'
                    : (_entries.length > 1
                        ? '${_entries.length} işlemi kaydet'
                        : 'Kaydet')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ClinicProvider>();

    for (final e in _entries) {
      final shares = _sharesOf(e);
      final name = _isManual(e) ? e.manualNameCtrl.text.trim() : e.procedure.name;
      final pct = _isManual(e) ? _manualPctOf(e) : e.procedure.percentage;
      final price = _priceOf(e);
      final collected = _collectedOf(e);
      final doctorPaid = collected >= price - 0.005 ? e.doctorPaid : false;

      final treatment = Treatment(
        id: e.existingId ?? provider.newTreatmentId(),
        patientId: widget.patientId,
        clinicId: _editing?.clinicId ?? provider.activeClinicId,
        procedureId: e.procedure.id,
        procedureName: name,
        model: e.procedure.model,
        teeth: e.teeth.toList()..sort(),
        totalPrice: price,
        labFee: e.procedure.requiresLabFee ? _labFeeOf(e) : 0,
        percentage: pct,
        netAmount: e.procedure.netAmount,
        cardCommissionRate: _cardRateOf(e),
        doctorShare: shares.doctor,
        clinicShare: shares.clinic,
        appointmentDate: _date,
        note: e.noteCtrl.text.trim(),
        installmentCount: e.installments,
        collectedAmount: collected,
        doctorPaid: doctorPaid,
        photos: e.photos,
        createdAt: e.createdAt ?? DateTime.now(),
      );
      await provider.saveTreatment(treatment);

      // Kaydetme anında: çıkarılan (artık kayıtta olmayan) hem eski hem de
      // bu oturumda çekilen fotoğraf dosyalarını sil — öksüz dosya bırakma.
      final orphans = {...e.originalPhotos, ...e.captured}
          .where((p) => !e.photos.contains(p));
      for (final path in orphans) {
        await PhotoStorage.delete(path);
      }
    }

    _saved = true;
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('İşlemi sil'),
        content: const Text('Bu işlem kaydı silinecek. Emin misin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok == true && _editing != null && mounted) {
      await context.read<ClinicProvider>().deleteTreatment(_editing!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }
}
