import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/demo_seeder.dart';
import '../../data/local/hive_boxes.dart';
import '../../data/models/patient.dart';
import '../../data/models/treatment.dart';
import '../../data/repositories/clinic_repository.dart';

/// Belirli bir zaman aralığındaki özet istatistikler.
class PeriodStats {
  final double total; // Toplam ciro
  final double doctor; // Özgür'e kalan
  final double clinic; // Kliniğe kalan
  final double paid; // Tahsil edilen
  final double unpaid; // Bekleyen
  final int procedureCount;
  final int patientCount;

  const PeriodStats({
    this.total = 0,
    this.doctor = 0,
    this.clinic = 0,
    this.paid = 0,
    this.unpaid = 0,
    this.procedureCount = 0,
    this.patientCount = 0,
  });
}

enum StatsRange { day, month, year }

/// Uygulamanın merkezi durum yöneticisi.
class ClinicProvider extends ChangeNotifier {
  ClinicProvider(this._repo);

  final ClinicRepository _repo;
  final _uuid = const Uuid();

  List<Patient> _patients = [];
  List<Treatment> _treatments = [];
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> load() async {
    await _maybeSeedDemo();
    _patients = _repo.getPatients()..sort((a, b) => a.name.compareTo(b.name));
    _treatments = _repo.getTreatments();
    _loaded = true;
    notifyListeners();
  }

  /// Demo verisini yalnızca bir kez oluşturur (meta_box 'demo_v1' bayrağı).
  /// Kaldırmak istersen bu çağrıyı silebilirsin.
  Future<void> _maybeSeedDemo() async {
    if (HiveBoxes.metaBox.get('demo_v1') == true) return;
    try {
      await DemoSeeder.seed(_repo);
    } finally {
      await HiveBoxes.metaBox.put('demo_v1', true);
    }
  }

  // ---------------------------------------------------------------------------
  // HASTALAR
  // ---------------------------------------------------------------------------
  List<Patient> get patients => List.unmodifiable(_patients);

  List<Patient> searchPatients(String query) {
    if (query.trim().isEmpty) return patients;
    final q = query.toLowerCase().trim();
    return _patients
        .where((p) =>
            p.name.toLowerCase().contains(q) || p.phone.contains(q))
        .toList();
  }

  Patient? patientById(String id) {
    for (final p in _patients) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<Patient> addPatient({
    required String name,
    String phone = '',
    String note = '',
  }) async {
    final patient = Patient(
      id: _uuid.v4(),
      name: name.trim(),
      phone: phone.trim(),
      note: note.trim(),
      createdAt: DateTime.now(),
    );
    await _repo.savePatient(patient);
    _patients.add(patient);
    _patients.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
    return patient;
  }

  Future<void> updatePatient(Patient patient) async {
    await _repo.savePatient(patient);
    final i = _patients.indexWhere((p) => p.id == patient.id);
    if (i != -1) _patients[i] = patient;
    _patients.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  Future<void> deletePatient(String id) async {
    await _repo.deletePatient(id);
    _patients.removeWhere((p) => p.id == id);
    _treatments.removeWhere((t) => t.patientId == id);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // İŞLEMLER
  // ---------------------------------------------------------------------------
  List<Treatment> get treatments => List.unmodifiable(_treatments);

  List<Treatment> treatmentsForPatient(String patientId) {
    final list =
        _treatments.where((t) => t.patientId == patientId).toList();
    list.sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));
    return list;
  }

  String newTreatmentId() => _uuid.v4();

  Future<void> saveTreatment(Treatment treatment) async {
    await _repo.saveTreatment(treatment);
    final i = _treatments.indexWhere((t) => t.id == treatment.id);
    if (i == -1) {
      _treatments.add(treatment);
    } else {
      _treatments[i] = treatment;
    }
    notifyListeners();
  }

  Future<void> deleteTreatment(String id) async {
    await _repo.deleteTreatment(id);
    _treatments.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  Future<void> togglePaid(Treatment treatment) async {
    await saveTreatment(treatment.copyWith(isPaid: !treatment.isPaid));
  }

  // --- Hasta bazlı toplamlar ---
  double patientTotal(String patientId) => treatmentsForPatient(patientId)
      .fold(0.0, (sum, t) => sum + t.totalPrice);

  double patientUnpaid(String patientId) => treatmentsForPatient(patientId)
      .where((t) => !t.isPaid)
      .fold(0.0, (sum, t) => sum + t.totalPrice);

  // ---------------------------------------------------------------------------
  // RANDEVULAR
  // ---------------------------------------------------------------------------
  List<Treatment> get todaysAppointments {
    final now = DateTime.now();
    final list = _treatments.where((t) {
      final d = t.appointmentDate;
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).toList();
    list.sort((a, b) => a.appointmentDate.compareTo(b.appointmentDate));
    return list;
  }

  List<Treatment> get upcomingAppointments {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final list = _treatments.where((t) {
      final d = DateTime(t.appointmentDate.year, t.appointmentDate.month,
          t.appointmentDate.day);
      return d.isAfter(today);
    }).toList();
    list.sort((a, b) => a.appointmentDate.compareTo(b.appointmentDate));
    return list;
  }

  // ---------------------------------------------------------------------------
  // İSTATİSTİK
  // ---------------------------------------------------------------------------
  bool _inRange(DateTime d, DateTime ref, StatsRange range) {
    switch (range) {
      case StatsRange.day:
        return d.year == ref.year && d.month == ref.month && d.day == ref.day;
      case StatsRange.month:
        return d.year == ref.year && d.month == ref.month;
      case StatsRange.year:
        return d.year == ref.year;
    }
  }

  List<Treatment> treatmentsInPeriod(DateTime ref, StatsRange range) {
    return _treatments
        .where((t) => _inRange(t.appointmentDate, ref, range))
        .toList()
      ..sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));
  }

  PeriodStats statsFor(DateTime ref, StatsRange range) {
    final items = treatmentsInPeriod(ref, range);
    double total = 0, doctor = 0, clinic = 0, paid = 0, unpaid = 0;
    final patientIds = <String>{};
    for (final t in items) {
      total += t.totalPrice;
      doctor += t.doctorShare;
      clinic += t.clinicShare;
      if (t.isPaid) {
        paid += t.totalPrice;
      } else {
        unpaid += t.totalPrice;
      }
      patientIds.add(t.patientId);
    }
    return PeriodStats(
      total: total,
      doctor: doctor,
      clinic: clinic,
      paid: paid,
      unpaid: unpaid,
      procedureCount: items.length,
      patientCount: patientIds.length,
    );
  }

  /// İşlem türüne göre kırılım (istatistik ekranı için).
  Map<String, ({int count, double total, double doctor})> breakdownByProcedure(
      DateTime ref, StatsRange range) {
    final map = <String, ({int count, double total, double doctor})>{};
    for (final t in treatmentsInPeriod(ref, range)) {
      final prev = map[t.procedureName] ??
          (count: 0, total: 0.0, doctor: 0.0);
      map[t.procedureName] = (
        count: prev.count + 1,
        total: prev.total + t.totalPrice,
        doctor: prev.doctor + t.doctorShare,
      );
    }
    return map;
  }
}
