import 'package:uuid/uuid.dart';

import '../../core/constants/procedure_catalog.dart';
import '../models/patient.dart';
import '../models/treatment.dart';
import '../repositories/clinic_repository.dart';
import 'photo_storage.dart';

/// Uygulamayı denemek için gerçekçi örnek (demo) veri oluşturur.
/// Yalnızca bir kez çalışır (bkz. ClinicProvider ve meta_box 'demo_v1').
class DemoSeeder {
  DemoSeeder._();

  static const _uuid = Uuid();

  static Future<void> seed(ClinicRepository repo) async {
    final now = DateTime.now();
    DateTime at(int dayOffset, int hour, [int minute = 0]) {
      final base = now.add(Duration(days: dayOffset));
      return DateTime(base.year, base.month, base.day, hour, minute);
    }

    // Örnek fotoğrafları cihaza kopyala.
    final oncesi = await PhotoStorage.saveAssetImage('assets/demo/foto_oncesi.png');
    final sonrasi =
        await PhotoStorage.saveAssetImage('assets/demo/foto_sonrasi.png');
    final rontgen =
        await PhotoStorage.saveAssetImage('assets/demo/foto_rontgen.png');
    final kontrol =
        await PhotoStorage.saveAssetImage('assets/demo/foto_kontrol.png');

    Future<Patient> addPatient(String name, String phone, String note) async {
      final p = Patient(
        id: _uuid.v4(),
        name: name,
        phone: phone,
        note: note,
        createdAt: now.subtract(const Duration(days: 40)),
      );
      await repo.savePatient(p);
      return p;
    }

    Future<void> addTreatment(
      Patient patient,
      String procedureId, {
      required List<String> teeth,
      required double price,
      required DateTime date,
      double labFee = 0,
      bool paid = true,
      double? collected,
      bool doctorPaid = true,
      int installments = 1,
      String note = '',
      List<String> photos = const [],
    }) async {
      final proc = ProcedureCatalog.byId(procedureId)!;
      final shares = proc.computeShares(totalPrice: price, labFee: labFee);
      // 'paid' geriye dönük kolaylık: true → tamamı tahsil + doktor aldı,
      // false → hiç tahsil edilmedi. 'collected' verilirse o öncelikli.
      final collectedAmount = collected ?? (paid ? price : 0);
      final gotDoctorPaid = collected != null ? doctorPaid : (paid && doctorPaid);
      final t = Treatment(
        id: _uuid.v4(),
        patientId: patient.id,
        procedureId: proc.id,
        procedureName: proc.name,
        model: proc.model,
        teeth: teeth,
        totalPrice: price,
        labFee: labFee,
        percentage: proc.percentage,
        netAmount: proc.netAmount,
        doctorShare: shares.doctor,
        clinicShare: shares.clinic,
        appointmentDate: date,
        note: note,
        installmentCount: installments,
        collectedAmount: collectedAmount,
        doctorPaid: gotDoctorPaid,
        photos: photos,
        createdAt: date,
      );
      await repo.saveTreatment(t);
    }

    // --- 1. Ayşe Yılmaz ---
    final ayse = await addPatient(
        'Ayşe Yılmaz', '0532 111 22 33', 'Penisilin alerjisi var.');
    await addTreatment(ayse, 'dolgu',
        teeth: ['16'], price: 2500, date: at(-18, 10, 30));
    await addTreatment(ayse, 'kanal',
        teeth: ['26'], price: 4000, date: at(-12, 14),
        note: '3 kanallı, retreatment ihtimali konuşuldu.');
    await addTreatment(ayse, 'dis_tasi',
        teeth: ['11', '21'], price: 1500, date: at(-4, 9, 15),
        // Klinik tahsil etti ama doktor payını henüz almadı.
        collected: 1500, doctorPaid: false);
    await addTreatment(ayse, 'beyazlatma',
        teeth: ['13', '12', '11', '21', '22', '23'],
        price: 5000,
        date: at(4, 16),
        paid: false,
        note: 'Randevu: ofis tipi beyazlatma.');

    // --- 2. Mehmet Demir ---
    final mehmet = await addPatient('Mehmet Demir', '0505 444 55 66', '');
    await addTreatment(mehmet, 'implant',
        teeth: ['46'],
        price: 16000,
        date: at(-20, 11),
        note: 'Cerrahi sorunsuz, 3 ay sonra üst yapı.',
        photos: [rontgen, oncesi, sonrasi]);
    await addTreatment(mehmet, 'kaplama_zirkon',
        teeth: ['36'], price: 8000, labFee: 2200, date: at(-6, 13, 30),
        // Klinik tahsil etti, doktor payını bekliyor.
        collected: 8000, doctorPaid: false,
        photos: [oncesi, sonrasi]);
    await addTreatment(mehmet, 'cekim',
        teeth: ['48'], price: 2000, date: at(0, 15),
        // Taksitli: 3 taksitin biri tahsil edildi.
        collected: 800, installments: 3, doctorPaid: false);
    await addTreatment(mehmet, 'implant_ustu',
        teeth: ['46'], price: 5000, date: at(7, 10), paid: false,
        note: 'İmplant üstü kron randevusu.');

    // --- 3. Zeynep Kaya ---
    final zeynep =
        await addPatient('Zeynep Kaya', '0543 777 88 99', 'Gebe (2. trimester).');
    await addTreatment(zeynep, 'dolgu',
        teeth: ['24', '25'], price: 4500, date: at(-9, 9));
    await addTreatment(zeynep, 'fissur_sealent',
        teeth: ['16', '26'], price: 1600, date: at(-9, 9, 40));
    await addTreatment(zeynep, 'kuretaj',
        teeth: ['31', '41'], price: 2500, date: at(2, 11, 30), paid: false);

    // --- 4. Emre Şahin ---
    final emre = await addPatient('Emre Şahin', '0530 222 33 44', '');
    await addTreatment(emre, 'kanal',
        teeth: ['37'], price: 4200, date: at(-15, 10),
        photos: [oncesi]);
    await addTreatment(emre, 'post',
        teeth: ['37'], price: 2000, date: at(-8, 10, 30));
    await addTreatment(emre, 'kaplama_metal',
        teeth: ['37'], price: 6000, labFee: 1500, date: at(-1, 14),
        photos: [oncesi, sonrasi]);
    await addTreatment(emre, 'retreatment',
        teeth: ['36'], price: 5000, date: at(5, 16, 30), paid: false,
        note: 'Randevu: eski kanal tedavisi yenilenecek.');

    // --- 5. Fatma Çelik ---
    final fatma =
        await addPatient('Fatma Çelik', '0555 888 11 22', 'Süt dişi takibi (çocuk).');
    await addTreatment(fatma, 'dis_tasi',
        teeth: ['11', '21', '31', '41'], price: 1500, date: at(-11, 12));
    await addTreatment(fatma, 'dolgu',
        teeth: ['54', '64'], price: 3000, date: at(-11, 12, 30),
        note: 'Süt dişi dolguları.');
    await addTreatment(fatma, 'beyazlatma',
        teeth: ['13', '12', '11', '21', '22', '23'],
        price: 5500,
        date: at(0, 17),
        photos: [oncesi, sonrasi, kontrol]);
    await addTreatment(fatma, 'kuretaj',
        teeth: ['46', '47'], price: 2800, date: at(9, 10), paid: false,
        note: 'Kontrol randevusu.');
  }
}
