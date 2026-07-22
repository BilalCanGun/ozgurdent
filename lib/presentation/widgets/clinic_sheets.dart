import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/clinic.dart';
import '../providers/clinic_provider.dart';
import '../screens/clinics_screen.dart';
import 'app_card.dart';

/// Klinik değiştirme alt sayfası: aktif kliniği seç, yeni ekle veya yönet.
Future<void> showClinicSwitcher(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => const _ClinicSwitcherSheet(),
  );
}

class _ClinicSwitcherSheet extends StatelessWidget {
  const _ClinicSwitcherSheet();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicProvider>();
    final clinics = provider.clinics;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Row(
              children: [
                Icon(Icons.local_hospital_outlined, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Klinik Seç',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ClinicsScreen()));
                  },
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('Yönet'),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              children: [
                for (final c in clinics)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _clinicRow(context, provider, c),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final created = await showClinicEditor(context);
                  if (created != null && context.mounted) {
                    await context.read<ClinicProvider>().setActiveClinic(created.id);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Yeni klinik ekle'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _clinicRow(
      BuildContext context, ClinicProvider provider, Clinic c) {
    final active = c.id == provider.activeClinicId;
    final color = AppColors.clinicColor(c.colorIndex);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      color: active ? color.withValues(alpha: 0.10) : null,
      onTap: () async {
        await provider.setActiveClinic(c.id);
        if (context.mounted) Navigator.pop(context);
      },
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.local_hospital, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              c.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (active)
            Icon(Icons.check_circle, color: color)
          else
            Icon(Icons.radio_button_unchecked, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

/// Klinik ekleme/düzenleme alt sayfası. Kaydedilen kliniği döner.
Future<Clinic?> showClinicEditor(BuildContext context, {Clinic? existing}) {
  return showModalBottomSheet<Clinic>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _ClinicEditor(existing: existing),
  );
}

class _ClinicEditor extends StatefulWidget {
  final Clinic? existing;
  const _ClinicEditor({this.existing});

  @override
  State<_ClinicEditor> createState() => _ClinicEditorState();
}

class _ClinicEditorState extends State<_ClinicEditor> {
  late final TextEditingController _nameCtrl;
  late int _colorIndex;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _colorIndex = widget.existing?.colorIndex ?? 0;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Klinik adı gerekli.')),
      );
      return;
    }
    final provider = context.read<ClinicProvider>();
    Clinic result;
    if (_isEdit) {
      result = widget.existing!.copyWith(name: name, colorIndex: _colorIndex);
      await provider.updateClinic(result);
    } else {
      result = await provider.addClinic(name, colorIndex: _colorIndex);
    }
    if (mounted) Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final palette = AppColors.clinicPalette;

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
                _isEdit ? 'Kliniği Düzenle' : 'Yeni Klinik',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Klinik adı',
                  prefixIcon: Icon(Icons.local_hospital_outlined),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Renk',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (int i = 0; i < palette.length; i++)
                    GestureDetector(
                      onTap: () => setState(() => _colorIndex = i),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: palette[i],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _colorIndex == i
                                ? AppColors.textPrimary
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: _colorIndex == i
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 20)
                            : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 22),
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
}
