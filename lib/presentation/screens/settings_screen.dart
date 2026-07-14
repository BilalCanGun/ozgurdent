import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../data/local/export_service.dart';
import '../../data/local/import_service.dart';
import '../../data/models/procedure_type.dart';
import '../providers/clinic_provider.dart';
import '../providers/notification_controller.dart';
import '../providers/theme_controller.dart';
import '../widgets/app_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final provider = context.watch<ClinicProvider>();
    final notif = context.watch<NotificationController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: SafeArea(
        child: Center(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
            children: [
              _sectionLabel('Görünüm'),
              const SizedBox(height: 10),
              _darkModeCard(theme),
              const SizedBox(height: 24),
              _sectionLabel('Bildirimler'),
              const SizedBox(height: 10),
              _notificationCard(context, notif, provider),
              const SizedBox(height: 24),
              _sectionLabel('Veri'),
              const SizedBox(height: 10),
              _ExportCard(),
              const SizedBox(height: 10),
              _ImportCard(),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _sectionLabel('İşlemler & Fiyatlandırma')),
                  TextButton.icon(
                    onPressed: () => _editProcedure(context, null),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Ekle'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'İşlem ekle, sil veya fiyatlandırma kurallarını düzenle '
                '(yüzde, net tutar, teknisyen bedeli, varsayılan ücret).',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              ...provider.procedures.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _procedureTile(context, provider, p),
                  )),
            ],
          ),
        ),
      ),
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

  Widget _darkModeCard(ThemeController theme) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              theme.isDark ? Icons.dark_mode : Icons.light_mode,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Koyu Tema',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  theme.isDark ? 'Açık' : 'Kapalı',
                  style:
                      TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: theme.isDark,
            activeColor: AppColors.primary,
            onChanged: (v) => theme.setDark(v),
          ),
        ],
      ),
    );
  }

  Widget _notificationCard(
      BuildContext context, NotificationController notif, ClinicProvider provider) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  notif.enabled
                      ? Icons.notifications_active
                      : Icons.notifications_off_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Günlük randevu bildirimi',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Seçilen saatte o günün randevuları',
                      style: TextStyle(
                          fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Switch(
                value: notif.enabled,
                activeColor: AppColors.primary,
                onChanged: (v) => notif.setEnabled(v, provider),
              ),
            ],
          ),
          if (notif.enabled) ...[
            Divider(height: 20, color: AppColors.border),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: notif.time,
                );
                if (t != null) await notif.setTime(t, provider);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Bildirim saati',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      notif.time.format(context),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        fontSize: 15,
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _procedureTile(
      BuildContext context, ClinicProvider provider, ProcedureType p) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      onTap: () => _editProcedure(context, p),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.medical_services_outlined,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _ruleText(p),
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
            onPressed: () => _confirmDelete(context, provider, p),
          ),
          Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  String _ruleText(ProcedureType p) {
    final parts = <String>[];
    switch (p.model) {
      case PricingModel.percentage:
        parts.add('Yüzde ${Fmt.percent(p.percentage)}');
        break;
      case PricingModel.net:
        parts.add('Net ${Fmt.money(p.netAmount)}');
        break;
      case PricingModel.percentageAfterLab:
        parts.add('Teknisyen sonrası ${Fmt.percent(p.percentage)}');
        break;
    }
    if (p.defaultPrice > 0) parts.add('Varsayılan ${Fmt.money(p.defaultPrice)}');
    return parts.join(' • ');
  }

  Future<void> _confirmDelete(
      BuildContext context, ClinicProvider provider, ProcedureType p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('İşlemi sil'),
        content: Text('"${p.name}" katalogdan silinecek. '
            'Mevcut kayıtlar etkilenmez.'),
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
    if (ok == true) {
      await provider.deleteProcedure(p.id);
    }
  }

  void _editProcedure(BuildContext context, ProcedureType? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _ProcedureEditor(existing: existing),
    );
  }
}

/// Excel dışa aktarma kartı (yükleme durumunu yönetir).
class _ExportCard extends StatefulWidget {
  @override
  State<_ExportCard> createState() => _ExportCardState();
}

class _ExportCardState extends State<_ExportCard> {
  bool _busy = false;

  Future<void> _export() async {
    final provider = context.read<ClinicProvider>();
    if (!provider.hasTreatments) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aktarılacak işlem kaydı yok.')),
      );
      return;
    }
    // iPad paylaşım balonunun konumu için bu kartın konumu.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    setState(() => _busy = true);
    try {
      await ExportService.exportTreatments(
        treatments: provider.treatments,
        patients: provider.patients,
        sharePositionOrigin: origin,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dışa aktarma başarısız: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: _busy ? null : _export,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.table_view_outlined, color: AppColors.success),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Excel indir (.xlsx)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Tüm işlem ve tahsilat dökümünü dışa aktar',
                  style:
                      TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (_busy)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          else
            Icon(Icons.download, color: AppColors.primary),
        ],
      ),
    );
  }
}

/// Excel içe aktarma kartı (dışa aktarma ile aynı formatı okur).
class _ImportCard extends StatefulWidget {
  @override
  State<_ImportCard> createState() => _ImportCardState();
}

class _ImportCardState extends State<_ImportCard> {
  bool _busy = false;

  Future<void> _import() async {
    final provider = context.read<ClinicProvider>();
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;

    setState(() => _busy = true);
    try {
      final rows = await ImportService.readRows(path);
      final res = await provider.importRows(rows);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'İçe aktarıldı: ${res.patients} yeni hasta, '
            '${res.treatments} işlem'
            '${res.skipped > 0 ? ' • ${res.skipped} satır atlandı' : ''}.',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İçe aktarma başarısız: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: _busy ? null : _import,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.upload_file_outlined, color: AppColors.info),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Excel yükle (.xlsx)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Aynı formatta hasta/işlem kayıtlarını içe aktar',
                  style:
                      TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (_busy)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          else
            Icon(Icons.file_upload_outlined, color: AppColors.primary),
        ],
      ),
    );
  }
}

/// İşlem ekleme / düzenleme alt sayfası.
class _ProcedureEditor extends StatefulWidget {
  final ProcedureType? existing;
  const _ProcedureEditor({this.existing});

  @override
  State<_ProcedureEditor> createState() => _ProcedureEditorState();
}

class _ProcedureEditorState extends State<_ProcedureEditor> {
  final _nameCtrl = TextEditingController();
  final _pctCtrl = TextEditingController(text: '30');
  final _netCtrl = TextEditingController();
  final _defaultCtrl = TextEditingController();
  PricingModel _model = PricingModel.percentage;
  bool _requiresLab = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _model = e.model;
      _pctCtrl.text = (e.percentage * 100).toStringAsFixed(0);
      if (e.netAmount > 0) _netCtrl.text = _trim(e.netAmount);
      if (e.defaultPrice > 0) _defaultCtrl.text = _trim(e.defaultPrice);
      _requiresLab = e.requiresLabFee;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pctCtrl.dispose();
    _netCtrl.dispose();
    _defaultCtrl.dispose();
    super.dispose();
  }

  String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('İşlem adı gerekli.');
      return;
    }
    final pct =
        (double.tryParse(_pctCtrl.text.replaceAll(',', '.')) ?? 0) / 100;
    final net = double.tryParse(_netCtrl.text.replaceAll(',', '.')) ?? 0;
    final def = double.tryParse(_defaultCtrl.text.replaceAll(',', '.')) ?? 0;
    final requiresLab =
        _model == PricingModel.percentageAfterLab ? true : _requiresLab;

    // Fiyatlandırma doğrulaması: bozuk kural (0 tutar / 0 yüzde) engellenir.
    if (_model == PricingModel.net) {
      if (net <= 0) {
        _snack('Net tutar 0’dan büyük olmalı.');
        return;
      }
    } else {
      if (pct <= 0 || pct > 1) {
        _snack('Yüzde 1 ile 100 arasında olmalı.');
        return;
      }
    }

    final provider = context.read<ClinicProvider>();
    if (_isEdit) {
      await provider.updateProcedure(widget.existing!.copyWith(
        name: name,
        model: _model,
        percentage: pct,
        netAmount: net,
        defaultPrice: def,
        requiresLabFee: requiresLab,
      ));
    } else {
      await provider.addProcedure(
        name: name,
        model: _model,
        percentage: pct,
        netAmount: net,
        defaultPrice: def,
        requiresLabFee: requiresLab,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final showPct = _model != PricingModel.net;
    final showNet = _model == PricingModel.net;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isEdit ? 'İşlemi Düzenle' : 'Yeni İşlem',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'İşlem adı'),
              ),
              const SizedBox(height: 16),
              Text(
                'Fiyatlandırma modeli',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _modelOption(PricingModel.percentage, 'Yüzde',
                  'Toplam ücretin yüzdesi sana kalır'),
              _modelOption(PricingModel.net, 'Net (sabit) tutar',
                  'Sana sabit bir tutar kalır'),
              _modelOption(PricingModel.percentageAfterLab,
                  'Teknisyen düşülüp yüzde',
                  'Teknisyen bedeli düşülür, kalanın yüzdesi sana'),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (showPct)
                    Expanded(
                      child: TextField(
                        controller: _pctCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Yüzde',
                          suffixText: '%',
                        ),
                      ),
                    ),
                  if (showNet)
                    Expanded(
                      child: TextField(
                        controller: _netCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Net tutar',
                          suffixText: '₺',
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _defaultCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Varsayılan ücret',
                        suffixText: '₺',
                      ),
                    ),
                  ),
                ],
              ),
              if (_model != PricingModel.percentageAfterLab) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _requiresLab,
                  activeColor: AppColors.primary,
                  title: Text(
                    'Teknisyen bedeli sorulsun',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  onChanged: (v) => setState(() => _requiresLab = v),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: Text(_isEdit ? 'Güncelle' : 'Ekle'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modelOption(PricingModel model, String title, String subtitle) {
    final active = _model == model;
    return GestureDetector(
      onTap: () => setState(() => _model = model),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: 0.10)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppColors.primary : Colors.transparent,
            width: 1.3,
          ),
        ),
        child: Row(
          children: [
            Icon(
              active ? Icons.radio_button_checked : Icons.radio_button_off,
              color: active ? AppColors.primary : AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                        fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
