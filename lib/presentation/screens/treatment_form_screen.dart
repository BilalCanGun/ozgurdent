import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/procedure_catalog.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/local/photo_storage.dart';
import '../../data/models/procedure_type.dart';
import '../../data/models/treatment.dart';
import '../providers/clinic_provider.dart';
import '../widgets/app_card.dart';
import '../widgets/tooth_chart.dart';
import 'photo_viewer_screen.dart';

/// İşlem (ve aynı zamanda randevu) ekleme / düzenleme ekranı.
class TreatmentFormScreen extends StatefulWidget {
  final String patientId;
  final String? treatmentId;

  const TreatmentFormScreen({
    super.key,
    required this.patientId,
    this.treatmentId,
  });

  @override
  State<TreatmentFormScreen> createState() => _TreatmentFormScreenState();
}

class _TreatmentFormScreenState extends State<TreatmentFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late ProcedureType _procedure;
  Set<String> _teeth = {};

  final _priceCtrl = TextEditingController();
  final _labFeeCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _manualNameCtrl = TextEditingController();
  final _manualPctCtrl = TextEditingController(text: '30');

  DateTime _date = DateTime.now();
  bool _isPaid = false;
  List<String> _photos = [];

  Treatment? _editing;

  bool get _isEdit => widget.treatmentId != null;

  @override
  void initState() {
    super.initState();
    _procedure = ProcedureCatalog.all.first;

    if (_isEdit) {
      final provider = context.read<ClinicProvider>();
      _editing = provider.treatments
          .where((t) => t.id == widget.treatmentId)
          .cast<Treatment?>()
          .firstWhere((t) => true, orElse: () => null);
      final t = _editing;
      if (t != null) {
        _procedure = ProcedureCatalog.byId(t.procedureId) ??
            ProcedureCatalog.manual;
        if (t.procedureId == ProcedureCatalog.manual.id) {
          _manualNameCtrl.text = t.procedureName;
          _manualPctCtrl.text = (t.percentage * 100).toStringAsFixed(0);
        }
        _teeth = t.teeth.toSet();
        _priceCtrl.text = _trimNum(t.totalPrice);
        _labFeeCtrl.text = t.labFee > 0 ? _trimNum(t.labFee) : '';
        _noteCtrl.text = t.note;
        _date = t.appointmentDate;
        _isPaid = t.isPaid;
        _photos = [...t.photos];
      }
    }

    _priceCtrl.addListener(_refresh);
    _labFeeCtrl.addListener(_refresh);
    _manualPctCtrl.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _priceCtrl.dispose();
    _labFeeCtrl.dispose();
    _noteCtrl.dispose();
    _manualNameCtrl.dispose();
    _manualPctCtrl.dispose();
    super.dispose();
  }

  String _trimNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  double get _price => double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _labFee =>
      double.tryParse(_labFeeCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _manualPct =>
      (double.tryParse(_manualPctCtrl.text.replaceAll(',', '.')) ?? 0) / 100;

  bool get _isManual => _procedure.id == ProcedureCatalog.manual.id;

  PaymentShares get _shares => _procedure.computeShares(
        totalPrice: _price,
        labFee: _labFee,
        overridePercentage: _isManual ? _manualPct : null,
      );

  @override
  Widget build(BuildContext context) {
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
                _sectionTitle('İşlem Türü'),
                const SizedBox(height: 10),
                _procedurePicker(),
                if (_isManual) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _manualNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'İşlem adı',
                          ),
                          validator: (v) => _isManual &&
                                  (v == null || v.trim().isEmpty)
                              ? 'Gerekli'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _manualPctCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]'))
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Yüzde',
                            suffixText: '%',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                _sectionTitle('Diş Seçimi (FDI)'),
                const SizedBox(height: 4),
                const Text(
                  'İşlemin uygulanacağı dişleri seç.',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 14),
                AppCard(
                  padding: const EdgeInsets.all(10),
                  child: ToothChart(
                    selected: _teeth,
                    onChanged: (s) => setState(() => _teeth = s),
                  ),
                ),
                const SizedBox(height: 24),
                _sectionTitle('Ücret'),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Hastadan alınan toplam ücret *',
                    prefixIcon: Icon(Icons.payments_outlined),
                    suffixText: '₺',
                  ),
                  validator: (v) {
                    final val =
                        double.tryParse((v ?? '').replaceAll(',', '.')) ?? 0;
                    return val <= 0 ? 'Geçerli bir ücret gir' : null;
                  },
                ),
                if (_procedure.requiresLabFee) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _labFeeCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Teknisyen / laboratuvar bedeli',
                      prefixIcon: Icon(Icons.biotech_outlined),
                      suffixText: '₺',
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _sharePreview(),
                const SizedBox(height: 24),
                _sectionTitle('Randevu Tarihi'),
                const SizedBox(height: 10),
                _dateTimePickers(),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _sectionTitle('Fotoğraflar'),
                    const SizedBox(width: 8),
                    if (_photos.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_photos.length}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'İşlemin öncesi/sonrası fotoğraflarını ekle.',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                _photoSection(),
                const SizedBox(height: 24),
                _sectionTitle('Not & Ödeme'),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _noteCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'İşlem notu (opsiyonel)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                _paidSwitch(),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      );

  Widget _procedurePicker() {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: _openProcedureSheet,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.medical_services_outlined,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isManual && _manualNameCtrl.text.isNotEmpty
                      ? _manualNameCtrl.text
                      : _procedure.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  _pricingRuleText(_procedure),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.expand_more, color: AppColors.textSecondary),
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

  Future<void> _openProcedureSheet() async {
    final items = [...ProcedureCatalog.all, ProcedureCatalog.manual];
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
              const Padding(
                padding: EdgeInsets.all(16),
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
                  itemBuilder: (_, i) {
                    final p = items[i];
                    final active = p.id == _procedure.id;
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    _pricingRuleText(p),
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (active)
                              const Icon(Icons.check_circle,
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
        _procedure = selected;
        if (!selected.requiresLabFee) _labFeeCtrl.clear();
      });
    }
  }

  Widget _sharePreview() {
    final shares = _shares;
    return AppCard(
      color: AppColors.surfaceAlt,
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _shareBox(
                  'Sana Kalan',
                  shares.doctor,
                  AppColors.doctorShare,
                  Icons.account_balance_wallet_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _shareBox(
                  'Kliniğe Kalan',
                  shares.clinic,
                  AppColors.clinicShare,
                  Icons.business_outlined,
                ),
              ),
            ],
          ),
          if (_price > 0) ...[
            const SizedBox(height: 12),
            _shareBar(shares.doctor, shares.clinic),
          ],
        ],
      ),
    );
  }

  Widget _shareBox(String label, double value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            Fmt.money(value),
            style: TextStyle(
              fontSize: 19,
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
    );
  }

  Widget _shareBar(double doctor, double clinic) {
    final total = doctor + clinic;
    final dFlex = total <= 0 ? 1 : (doctor / total * 1000).round();
    final cFlex = total <= 0 ? 1 : (clinic / total * 1000).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Row(
        children: [
          Expanded(
            flex: dFlex == 0 ? 1 : dFlex,
            child: Container(height: 10, color: AppColors.doctorShare),
          ),
          Expanded(
            flex: cFlex == 0 ? 1 : cFlex,
            child: Container(height: 10, color: AppColors.clinicShare),
          ),
        ],
      ),
    );
  }

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
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
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
        _date =
            DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute);
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(
            _date.year, _date.month, _date.day, picked.hour, picked.minute);
      });
    }
  }

  Widget _paidSwitch() {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(
            _isPaid ? Icons.check_circle : Icons.schedule,
            color: _isPaid ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Ödeme alındı',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Switch(
            value: _isPaid,
            activeColor: AppColors.success,
            onChanged: (v) => setState(() => _isPaid = v),
          ),
        ],
      ),
    );
  }

  Widget _photoSection() {
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _addPhotoTile(),
          for (int i = 0; i < _photos.length; i++) _photoThumb(i),
        ],
      ),
    );
  }

  Widget _addPhotoTile() {
    return GestureDetector(
      onTap: _pickPhotoSource,
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.add_a_photo_outlined,
                color: AppColors.primary, size: 30),
            SizedBox(height: 6),
            Text(
              'Ekle',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoThumb(int i) {
    return GestureDetector(
      onTap: () => _openViewer(i),
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(_photos[i]), fit: BoxFit.cover),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _removePhoto(i),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close,
                      color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openViewer(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoViewerScreen(
          photos: _photos,
          initialIndex: index,
          onDelete: (i) => _removePhoto(i, deleteFile: true),
        ),
      ),
    );
  }

  Future<void> _pickPhotoSource() async {
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
              leading: const Icon(Icons.photo_camera_outlined,
                  color: AppColors.primary),
              title: const Text('Kamera ile çek'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.primary),
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
      if (path != null) setState(() => _photos.add(path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotoğraf eklenemedi.')),
        );
      }
    }
  }

  void _removePhoto(int i, {bool deleteFile = false}) {
    if (i < 0 || i >= _photos.length) return;
    final path = _photos[i];
    setState(() => _photos.removeAt(i));
    if (deleteFile) PhotoStorage.delete(path);
  }

  Widget _bottomBar() {
    final shares = _shares;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Sana kalan',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                Text(
                  Fmt.money(shares.doctor),
                  style: const TextStyle(
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
                label: Text(_isEdit ? 'Güncelle' : 'Kaydet'),
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
    final shares = _shares;
    final name = _isManual ? _manualNameCtrl.text.trim() : _procedure.name;
    final pct = _isManual ? _manualPct : _procedure.percentage;

    final treatment = Treatment(
      id: _editing?.id ?? provider.newTreatmentId(),
      patientId: widget.patientId,
      procedureId: _procedure.id,
      procedureName: name,
      model: _procedure.model,
      teeth: _teeth.toList()..sort(),
      totalPrice: _price,
      labFee: _procedure.requiresLabFee ? _labFee : 0,
      percentage: pct,
      netAmount: _procedure.netAmount,
      doctorShare: shares.doctor,
      clinicShare: shares.clinic,
      appointmentDate: _date,
      note: _noteCtrl.text.trim(),
      isPaid: _isPaid,
      photos: _photos,
      createdAt: _editing?.createdAt ?? DateTime.now(),
    );

    await provider.saveTreatment(treatment);
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
