// Yeni ödeme / tahsilat modeli ve haftalık aralık testleri.
import 'package:flutter_test/flutter_test.dart';

import 'package:ozgurdent/data/models/procedure_type.dart';
import 'package:ozgurdent/data/models/treatment.dart';
import 'package:ozgurdent/presentation/providers/clinic_provider.dart';

Treatment _make({
  double total = 1000,
  double collected = 0,
  bool doctorPaid = false,
  int installments = 1,
}) {
  return Treatment(
    id: 't1',
    patientId: 'p1',
    procedureId: 'dolgu',
    procedureName: 'Dolgu',
    model: PricingModel.percentage,
    teeth: const ['11'],
    totalPrice: total,
    labFee: 0,
    percentage: 0.30,
    netAmount: 0,
    doctorShare: total * 0.30,
    clinicShare: total * 0.70,
    appointmentDate: DateTime(2026, 7, 13),
    note: '',
    installmentCount: installments,
    collectedAmount: collected,
    doctorPaid: doctorPaid,
    createdAt: DateTime(2026, 7, 13),
  );
}

void main() {
  group('Ödeme aşamaları', () {
    test('Hiç tahsilat yok → pending', () {
      final t = _make(collected: 0);
      expect(t.stage, PaymentStage.pending);
      expect(t.clinicCollected, false);
      expect(t.remaining, 1000);
    });

    test('Kısmi tahsilat → partial', () {
      final t = _make(collected: 400);
      expect(t.stage, PaymentStage.partial);
      expect(t.partiallyCollected, true);
      expect(t.remaining, 600);
    });

    test('Klinik tahsil etti, doktor almadı → clinicCollected + uyarı', () {
      final t = _make(collected: 1000, doctorPaid: false);
      expect(t.stage, PaymentStage.clinicCollected);
      expect(t.clinicCollected, true);
      expect(t.awaitingDoctorPayout, true);
      expect(t.remaining, 0);
    });

    test('Tamamı tahsil + doktor aldı → settled', () {
      final t = _make(collected: 1000, doctorPaid: true);
      expect(t.stage, PaymentStage.settled);
      expect(t.fullySettled, true);
      expect(t.awaitingDoctorPayout, false);
    });
  });

  group('Serialleştirme', () {
    test('toMap/fromMap tur döngüsü alanları korur', () {
      final t = _make(collected: 500, doctorPaid: false, installments: 3);
      final back = Treatment.fromMap(t.toMap());
      expect(back.collectedAmount, 500);
      expect(back.installmentCount, 3);
      expect(back.doctorPaid, false);
    });

    test('Eski isPaid=true kaydı tam tahsil + doktor aldı olarak okunur', () {
      final legacy = {
        'id': 'x',
        'patientId': 'p',
        'procedureId': 'dolgu',
        'procedureName': 'Dolgu',
        'model': 'percentage',
        'teeth': ['11'],
        'totalPrice': 2000,
        'labFee': 0,
        'percentage': 0.30,
        'netAmount': 0,
        'doctorShare': 600,
        'clinicShare': 1400,
        'appointmentDate': DateTime(2026, 1, 1).toIso8601String(),
        'note': '',
        'isPaid': true,
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
      };
      final t = Treatment.fromMap(legacy);
      expect(t.clinicCollected, true);
      expect(t.doctorPaid, true);
      expect(t.collectedAmount, 2000);
    });
  });

  group('Haftanın başlangıcı', () {
    test('Pazartesi bulunur', () {
      // 2026-07-13 Pazartesi.
      final ws = ClinicProvider.weekStart(DateTime(2026, 7, 15, 14));
      expect(ws.year, 2026);
      expect(ws.month, 7);
      expect(ws.day, 13);
      expect(ws.hour, 0);
    });
  });
}
