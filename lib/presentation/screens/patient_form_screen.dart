import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/patient.dart';
import '../providers/clinic_provider.dart';
import '../providers/theme_controller.dart';

/// Yeni hasta ekleme veya mevcut hastayı düzenleme formu.
class PatientFormScreen extends StatefulWidget {
  final Patient? patient;
  const PatientFormScreen({super.key, this.patient});

  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _note;

  bool get _isEdit => widget.patient != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.patient?.name ?? '');
    _phone = TextEditingController(text: widget.patient?.phone ?? '');
    _note = TextEditingController(text: widget.patient?.note ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<ClinicProvider>();
    Patient result;
    if (_isEdit) {
      result = widget.patient!.copyWith(
        name: _name.text,
        phone: _phone.text,
        note: _note.text,
      );
      await provider.updatePatient(result);
    } else {
      result = await provider.addPatient(
        name: _name.text,
        phone: _phone.text,
        note: _note.text,
      );
    }
    if (mounted) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Hastayı Düzenle' : 'Yeni Hasta')),
      body: SafeArea(
        child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                  18, 18, 18, MediaQuery.viewInsetsOf(context).bottom + 24),
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Hasta Adı Soyadı *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Hasta adı gerekli'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefon (opsiyonel)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _note,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Not (opsiyonel)',
                    alignLabelWithHint: true,
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 60),
                      child: Icon(Icons.notes_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check),
                    label: Text(_isEdit ? 'Kaydet' : 'Hasta Ekle'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
