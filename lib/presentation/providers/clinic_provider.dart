import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/procedure_catalog.dart';
import '../../data/local/demo_seeder.dart';
import '../../data/local/hive_boxes.dart';
import '../../data/models/patient.dart';
import '../../data/models/procedure_type.dart';
import '../../data/models/treatment.dart';
import '../../data/repositories/clinic_repository.dart';

/// Belirli bir zaman aralığındaki özet istatistikler.
class PeriodStats {
  final double total; // Toplam ciro
  final double doctor; // Özgür'e kalan (hak ediş)
  final double clinic; // Kliniğe kalan
  final double collected; // Klinikçe tahsil edilen
  final double outstanding; // Hastadan bekleyen
  final double doctorPaid; // Doktorun aldığı pay
  final double doctorPending; // Klinik tahsil etti, doktor almadı
  final int procedureCount;
  final int patientCount;

  const PeriodStats({
    this.total = 0,
    this.doctor = 0,
    this.clinic = 0,
    this.collected = 0,
    this.outstanding = 0,
    this.doctorPaid = 0,
    this.doctorPending = 0,
    this.procedureCount = 0,
    this.patientCount = 0,
  });
}

enum StatsRange { day, week, month, year }

/// Uygulamanın merkezi durum yöneticisi.
class ClinicProvider extends ChangeNotifier {
  ClinicProvider(this._repo);

  final ClinicRepository _repo;
  final _uuid = const Uuid();

  List<Patient> _patients = [];
  List<Treatment> _treatments = [];
  List<ProcedureType> _procedures = [];
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> load() async {
    await _maybeSeedDemo();
    await _ensureProcedures();
    _patients = _repo.getPatients()..sort((a, b) => a.name.compareTo(b.name));
    _treatments = _repo.getTreatments();
    _procedures = _repo.getProcedures();
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

  /// İşlem kataloğunu ilk açılışta yerleşik listeden tohumlar.
  Future<void> _ensureProcedures() async {
    if (HiveBoxes.proceduresBox.isNotEmpty) return;
    for (final p in ProcedureCatalog.all) {
      await _repo.saveProcedure(p);
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
  // İŞLEM TANIMLARI (KATALOG)
  // ---------------------------------------------------------------------------
  List<ProcedureType> get procedures => List.unmodifiable(_procedures);

  ProcedureType? procedureById(String id) {
    for (final p in _procedures) {
      if (p.id == id) return p;
    }
    return ProcedureCatalog.byId(id);
  }

  String newProcedureId() => _uuid.v4();

  Future<ProcedureType> addProcedure({
    required String name,
    required PricingModel model,
    double percentage = 0.30,
    double netAmount = 0,
    double defaultPrice = 0,
    bool requiresLabFee = false,
  }) async {
    final proc = ProcedureType(
      id: _uuid.v4(),
      name: name.trim(),
      model: model,
      percentage: percentage,
      netAmount: netAmount,
      defaultPrice: defaultPrice,
      requiresLabFee: requiresLabFee,
    );
    await _repo.saveProcedure(proc);
    _procedures.add(proc);
    notifyListeners();
    return proc;
  }

  Future<void> updateProcedure(ProcedureType procedure) async {
    await _repo.saveProcedure(procedure);
    final i = _procedures.indexWhere((p) => p.id == procedure.id);
    if (i != -1) _procedures[i] = procedure;
    notifyListeners();
  }

  Future<void> deleteProcedure(String id) async {
    await _repo.deleteProcedure(id);
    _procedures.removeWhere((p) => p.id == id);
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

  // --- Ödeme / tahsilat güncellemeleri ---
  Future<void> updatePayment(
    Treatment treatment, {
    double? collectedAmount,
    bool? doctorPaid,
    int? installmentCount,
  }) async {
    await saveTreatment(treatment.copyWith(
      collectedAmount: collectedAmount,
      doctorPaid: doctorPaid,
      installmentCount: installmentCount,
    ));
  }

  /// Kliniğin tahsilat durumunu değiştirir (tam tahsil / sıfırla).
  Future<void> toggleClinicCollected(Treatment t) async {
    final collected = t.clinicCollected ? 0.0 : t.totalPrice;
    await updatePayment(t, collectedAmount: collected);
  }

  /// Doktor payı alındı durumunu değiştirir.
  Future<void> toggleDoctorPaid(Treatment t) async {
    await updatePayment(t, doctorPaid: !t.doctorPaid);
  }

  // --- Hasta bazlı toplamlar ---
  double patientTotal(String patientId) => treatmentsForPatient(patientId)
      .fold(0.0, (sum, t) => sum + t.totalPrice);

  double patientOutstanding(String patientId) =>
      treatmentsForPatient(patientId).fold(0.0, (sum, t) => sum + t.remaining);

  // ---------------------------------------------------------------------------
  // RANDEVULAR / TAKVİM
  // ---------------------------------------------------------------------------
  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<Treatment> appointmentsOn(DateTime day) {
    final list =
        _treatments.where((t) => _sameDay(t.appointmentDate, day)).toList();
    list.sort((a, b) => a.appointmentDate.compareTo(b.appointmentDate));
    return list;
  }

  List<Treatment> get todaysAppointments => appointmentsOn(DateTime.now());

  /// Bir ay içindeki her gün için randevu sayısı (takvim noktaları için).
  Map<int, int> appointmentCountsByDay(DateTime month) {
    final map = <int, int>{};
    for (final t in _treatments) {
      final d = t.appointmentDate;
      if (d.year == month.year && d.month == month.month) {
        map[d.day] = (map[d.day] ?? 0) + 1;
      }
    }
    return map;
  }

  // ---------------------------------------------------------------------------
  // DOKTOR PAYI BEKLEYENLER (klinik tahsil etti, doktor almadı)
  // ---------------------------------------------------------------------------
  List<Treatment> get awaitingDoctorPayout {
    final list = _treatments.where((t) => t.awaitingDoctorPayout).toList();
    list.sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));
    return list;
  }

  double get awaitingDoctorPayoutTotal =>
      awaitingDoctorPayout.fold(0.0, (s, t) => s + t.doctorShare);

  // ---------------------------------------------------------------------------
  // İSTATİSTİK
  // ---------------------------------------------------------------------------
  /// Verilen tarihin içinde bulunduğu haftanın (Pazartesi) başlangıcı.
  static DateTime weekStart(DateTime ref) {
    final d = DateTime(ref.year, ref.month, ref.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  bool _inRange(DateTime d, DateTime ref, StatsRange range) {
    switch (range) {
      case StatsRange.day:
        return _sameDay(d, ref);
      case StatsRange.week:
        final start = weekStart(ref);
        final end = start.add(const Duration(days: 7));
        final dd = DateTime(d.year, d.month, d.day);
        return !dd.isBefore(start) && dd.isBefore(end);
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
    double total = 0,
        doctor = 0,
        clinic = 0,
        collected = 0,
        outstanding = 0,
        doctorPaid = 0,
        doctorPending = 0;
    final patientIds = <String>{};
    for (final t in items) {
      total += t.totalPrice;
      doctor += t.doctorShare;
      clinic += t.clinicShare;
      collected += t.collectedAmount;
      outstanding += t.remaining;
      if (t.doctorPaid) {
        doctorPaid += t.doctorShare;
      } else if (t.clinicCollected) {
        doctorPending += t.doctorShare;
      }
      patientIds.add(t.patientId);
    }
    return PeriodStats(
      total: total,
      doctor: doctor,
      clinic: clinic,
      collected: collected,
      outstanding: outstanding,
      doctorPaid: doctorPaid,
      doctorPending: doctorPending,
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
