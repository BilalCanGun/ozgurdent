import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/treatment.dart';
import '../providers/clinic_provider.dart';

/// Bir işlemin tahsilat/ödeme durumunu düzenlemek için alt sayfa açar.
Future<void> showPaymentEditor(BuildContext context, Treatment treatment) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _PaymentEditorSheet(treatment: treatment),
  );
}

enum _CollectMode { pending, partial, full }

class _PaymentEditorSheet extends StatefulWidget {
  final Treatment treatment;
  const _PaymentEditorSheet({required this.treatment});

  @override
  State<_PaymentEditorSheet> createState() => _PaymentEditorSheetState();
}

class _PaymentEditorSheetState extends State<_PaymentEditorSheet> {
  late _CollectMode _mode;
  late int _installments;
  late bool _doctorPaid;
  final _amountCtrl = TextEditingController();

  Treatment get t => widget.treatment;

  @override
  void initState() {
    super.initState();
    _installments = t.installmentCount < 1 ? 1 : t.installmentCount;
    _doctorPaid = t.doctorPaid;
    if (t.clinicCollected) {
      _mode = _CollectMode.full;
    } else if (t.partiallyCollected) {
      _mode = _CollectMode.partial;
      _amountCtrl.text = _trim(t.collectedAmount);
    } else {
      _mode = _CollectMode.pending;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  double get _collected {
    switch (_mode) {
      case _CollectMode.pending:
        return 0;
      case _CollectMode.full:
        return t.totalPrice;
      case _CollectMode.partial:
        final v = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;
        return v.clamp(0, t.totalPrice).toDouble();
    }
  }

  Future<void> _save() async {
    final collected = _collected;
    // Doktor payı yalnızca klinik tamamını tahsil ettiyse alınmış sayılır.
    final doctorPaid = collected >= t.totalPrice - 0.005 ? _doctorPaid : false;
    await context.read<ClinicProvider>().updatePayment(
          t,
          collectedAmount: collected,
          doctorPaid: doctorPaid,
          installmentCount: _installments,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final clinicCollected = _collected >= t.totalPrice - 0.005;
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
                'Ödeme / Tahsilat',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${t.procedureName} • Toplam ${Fmt.money(t.totalPrice)}',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              _label('Klinik tahsilatı'),
              const SizedBox(height: 8),
              _modeSelector(),
              if (_mode == _CollectMode.partial) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Tahsil edilen tutar',
                    helperText: 'Kalan: ${Fmt.money(_remaining())}',
                    prefixIcon: const Icon(Icons.payments_outlined),
                    suffixText: '₺',
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final f in const [0.25, 0.5, 0.75])
                      ActionChip(
                        label: Text('%${(f * 100).toInt()}'),
                        onPressed: () => setState(() =>
                            _amountCtrl.text = _trim(t.totalPrice * f)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              _label('Taksit sayısı'),
              const SizedBox(height: 8),
              _installmentStepper(),
              const SizedBox(height: 18),
              _label('Doktor payı'),
              const SizedBox(height: 8),
              _doctorPaidTile(clinicCollected),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: const Text('Kaydet'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _remaining() {
    final r = t.totalPrice - _collected;
    return r < 0 ? 0 : r;
  }

  Widget _label(String s) => Text(
        s,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      );

  Widget _modeSelector() {
    Widget seg(String label, _CollectMode m, IconData icon, Color color) {
      final active = _mode == m;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _mode = m),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: active ? color.withValues(alpha: 0.14) : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? color : Colors.transparent,
                width: 1.4,
              ),
            ),
            child: Column(
              children: [
                Icon(icon,
                    size: 20,
                    color: active ? color : AppColors.textSecondary),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
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

    return Row(
      children: [
        seg('Bekliyor', _CollectMode.pending, Icons.schedule, AppColors.warning),
        seg('Kısmi', _CollectMode.partial, Icons.timelapse, AppColors.info),
        seg('Tamamı', _CollectMode.full, Icons.check_circle, AppColors.success),
      ],
    );
  }

  Widget _installmentStepper() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _installments > 1
                ? () => setState(() => _installments--)
                : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Expanded(
            child: Center(
              child: Text(
                _installments == 1 ? 'Peşin' : '$_installments taksit',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _installments < 12
                ? () => setState(() => _installments++)
                : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }

  Widget _doctorPaidTile(bool clinicCollected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            _doctorPaid ? Icons.verified : Icons.account_balance_wallet_outlined,
            color: _doctorPaid ? AppColors.success : AppColors.violet,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Doktor payını aldı',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  clinicCollected
                      ? 'Pay: ${Fmt.money(t.doctorShare)}'
                      : 'Önce klinik tahsilatı tamamlanmalı',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _doctorPaid && clinicCollected,
            activeColor: AppColors.success,
            onChanged: clinicCollected
                ? (v) => setState(() => _doctorPaid = v)
                : null,
          ),
        ],
      ),
    );
  }
}
