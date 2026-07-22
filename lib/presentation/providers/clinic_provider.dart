import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/procedure_catalog.dart';
import '../../data/local/demo_seeder.dart';
import '../../data/local/hive_boxes.dart';
import '../../data/models/clinic.dart';
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

/// Bir hasta için önceden hesaplanmış özetler (liste ekranında O(1) erişim).
typedef PatientAggregate = ({
  double total,
  double outstanding,
  int count,
  double awaitingPayout, // klinik tahsil etti, doktor payı bekliyor (toplam)
});

enum StatsRange { day, week, month, year }

/// Uygulamanın merkezi durum yöneticisi.
///
/// Büyük veri kümelerinde (binlerce/on binlerce işlem) performans için
/// sık kullanılan sorgular indekslenir; ekranlar her karede tüm listeyi
/// taramak yerine hazır haritalardan okur.
class ClinicProvider extends ChangeNotifier {
  ClinicProvider(this._repo);

  final ClinicRepository _repo;
  final _uuid = const Uuid();

  List<Patient> _patients = [];
  List<Treatment> _treatments = []; // TÜM klinikler (depolama).
  List<ProcedureType> _procedures = []; // TÜM klinikler (depolama).
  List<Clinic> _clinics = [];
  String _activeClinicId = '';
  bool _loaded = false;

  // --- İndeksler (mutasyonlarda yeniden kurulur) ---
  /// Aktif kliniğe ait işlemler (sorgular bunun üzerinden çalışır).
  List<Treatment> _active = const [];
  final Map<String, Patient> _patientIndex = {};
  final Map<String, List<Treatment>> _byPatient = {};
  final Map<String, PatientAggregate> _agg = {};
  List<Treatment> _awaiting = const [];
  double _awaitingTotal = 0;

  bool get isLoaded => _loaded;

  Future<void> load() async {
    await _maybeSeedDemo();
    _patients = _repo.getPatients()..sort(_patientSort);
    _treatments = _repo.getTreatments();
    _procedures = _repo.getProcedures();
    await _ensureClinicsAndMigrate();
    _rebuildIndexes();
    _loaded = true;
    notifyListeners();
  }

  /// En az bir klinik olmasını sağlar; eski (kliniksiz) işlem/işlem-tanımı
  /// kayıtlarını varsayılan kliniğe taşır; aktif kliniği belirler.
  Future<void> _ensureClinicsAndMigrate() async {
    _clinics = _repo.getClinics()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    if (_clinics.isEmpty) {
      final def = Clinic(
        id: _uuid.v4(),
        name: 'Ana Klinik',
        colorIndex: 0,
        createdAt: DateTime.now(),
      );
      await _repo.saveClinic(def);
      _clinics = [def];
    }
    final defaultId = _clinics.first.id;

    // İşlem tanımları: hiç yoksa varsayılan katalogla tohumla; kliniksiz
    // (eski) kayıtları varsayılan kliniğe bağla.
    if (_procedures.isEmpty) {
      for (final p in ProcedureCatalog.all) {
        await _repo.saveProcedure(p.copyWith(clinicId: defaultId));
      }
      _procedures = _repo.getProcedures();
    } else {
      final orphans =
          _procedures.where((p) => p.clinicId.isEmpty).toList();
      if (orphans.isNotEmpty) {
        for (final p in orphans) {
          await _repo.saveProcedure(p.copyWith(clinicId: defaultId));
        }
        _procedures = _repo.getProcedures();
      }
    }

    // İşlemler: kliniksiz (eski) kayıtları varsayılan kliniğe bağla.
    final orphanTx = _treatments.where((t) => t.clinicId.isEmpty).toList();
    if (orphanTx.isNotEmpty) {
      for (final t in orphanTx) {
        await _repo.saveTreatment(t.copyWith(clinicId: defaultId));
      }
      _treatments = _repo.getTreatments();
    }

    final stored = _repo.getSetting<String>('active_clinic_id');
    _activeClinicId = (stored != null && _clinics.any((c) => c.id == stored))
        ? stored
        : defaultId;
  }

  /// Türkçe-duyarlı hasta sıralaması (İ/ı, Ş, Ç, Ö, Ü doğru yerlerde).
  static final _trCollator = _TrCollator();
  int _patientSort(Patient a, Patient b) =>
      _trCollator.compare(a.name, b.name);

  /// İndeksleri (hasta haritası, hasta bazlı işlem listeleri, özetler ve
  /// doktor payı bekleyenler) tek geçişte yeniden kurar.
  void _rebuildIndexes() {
    // Aktif kliniğe göre işlemleri süz — tüm sorgular bu küme üzerinden çalışır.
    _active = _treatments
        .where((t) => t.clinicId == _activeClinicId)
        .toList(growable: false);

    _patientIndex.clear();
    for (final p in _patients) {
      _patientIndex[p.id] = p;
    }

    _byPatient.clear();
    for (final t in _active) {
      (_byPatient[t.patientId] ??= <Treatment>[]).add(t);
    }
    _agg.clear();
    for (final entry in _byPatient.entries) {
      final list = entry.value
        ..sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));
      double total = 0, outstanding = 0, awaitingPayout = 0;
      for (final t in list) {
        total += t.totalPrice;
        outstanding += t.remaining;
        if (t.awaitingDoctorPayout) awaitingPayout += t.doctorShare;
      }
      _agg[entry.key] = (
        total: total,
        outstanding: outstanding,
        count: list.length,
        awaitingPayout: awaitingPayout,
      );
    }

    final awaiting = <Treatment>[];
    double awaitingTotal = 0;
    for (final t in _active) {
      if (t.awaitingDoctorPayout) {
        awaiting.add(t);
        awaitingTotal += t.doctorShare;
      }
    }
    awaiting.sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));
    _awaiting = awaiting;
    _awaitingTotal = awaitingTotal;
  }

  /// Demo verisini yalnızca bir kez oluşturur (meta_box 'demo_v1' bayrağı).
  /// Yayına çıkarken bu sahte veri üretimi devre dışı: sadece debug modda.
  Future<void> _maybeSeedDemo() async {
    if (!kDebugMode) return;
    if (HiveBoxes.metaBox.get('demo_v1') == true) return;
    try {
      await DemoSeeder.seed(_repo);
    } finally {
      await HiveBoxes.metaBox.put('demo_v1', true);
    }
  }

  // ---------------------------------------------------------------------------
  // KLİNİKLER
  // ---------------------------------------------------------------------------
  List<Clinic> get clinics => List.unmodifiable(_clinics);
  String get activeClinicId => _activeClinicId;

  Clinic? get activeClinic {
    for (final c in _clinics) {
      if (c.id == _activeClinicId) return c;
    }
    return _clinics.isEmpty ? null : _clinics.first;
  }

  /// Aktif kliniği değiştirir; tüm sorgular yeni kliniğe göre yeniden kurulur.
  Future<void> setActiveClinic(String id) async {
    if (id == _activeClinicId) return;
    if (!_clinics.any((c) => c.id == id)) return;
    _activeClinicId = id;
    await _repo.setSetting('active_clinic_id', id);
    _rebuildIndexes();
    notifyListeners();
  }

  /// Yeni klinik ekler ve varsayılan işlem kataloğuyla (kliniğe özel
  /// kopyalar) tohumlar.
  Future<Clinic> addClinic(String name, {int? colorIndex}) async {
    final clinic = Clinic(
      id: _uuid.v4(),
      name: name.trim(),
      colorIndex: colorIndex ?? _clinics.length,
      createdAt: DateTime.now(),
    );
    await _repo.saveClinic(clinic);
    _clinics.add(clinic);
    // Varsayılan katalogdan bu kliniğe özel kopyalar üret.
    for (final p in ProcedureCatalog.all) {
      final proc = p.copyWith(id: _uuid.v4(), clinicId: clinic.id);
      await _repo.saveProcedure(proc);
      _procedures.add(proc);
    }
    notifyListeners();
    return clinic;
  }

  /// Bir kliniğe ait toplam işlem sayısı (tüm zamanlar).
  int clinicTreatmentCount(String id) =>
      _treatments.where((t) => t.clinicId == id).length;

  Future<void> updateClinic(Clinic clinic) async {
    await _repo.saveClinic(clinic);
    final i = _clinics.indexWhere((c) => c.id == clinic.id);
    if (i != -1) _clinics[i] = clinic;
    notifyListeners();
  }

  /// Kliniği ve ona ait işlemleri/işlem tanımlarını siler.
  /// En az bir klinik her zaman kalır.
  Future<void> deleteClinic(String id) async {
    if (_clinics.length <= 1) return;
    await _repo.deleteClinic(id);
    _clinics.removeWhere((c) => c.id == id);
    _treatments.removeWhere((t) => t.clinicId == id);
    _procedures.removeWhere((p) => p.clinicId == id);
    if (_activeClinicId == id) {
      _activeClinicId = _clinics.first.id;
      await _repo.setSetting('active_clinic_id', _activeClinicId);
    }
    _rebuildIndexes();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // HASTALAR
  // ---------------------------------------------------------------------------
  List<Patient> get patients => List.unmodifiable(_patients);
  int get patientCount => _patients.length;

  List<Patient> searchPatients(String query) {
    if (query.trim().isEmpty) return _patients;
    final q = query.toLowerCase().trim();
    return _patients
        .where((p) =>
            p.name.toLowerCase().contains(q) || p.phone.contains(q))
        .toList();
  }

  Patient? patientById(String id) => _patientIndex[id];

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
    _patients.sort(_patientSort);
    _rebuildIndexes();
    notifyListeners();
    return patient;
  }

  Future<void> updatePatient(Patient patient) async {
    await _repo.savePatient(patient);
    final i = _patients.indexWhere((p) => p.id == patient.id);
    if (i != -1) _patients[i] = patient;
    _patients.sort(_patientSort);
    _rebuildIndexes();
    notifyListeners();
  }

  Future<void> deletePatient(String id) async {
    await _repo.deletePatient(id);
    _patients.removeWhere((p) => p.id == id);
    _treatments.removeWhere((t) => t.patientId == id);
    _rebuildIndexes();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // İŞLEM TANIMLARI (KATALOG)
  // ---------------------------------------------------------------------------
  /// Aktif kliniğin işlem kataloğu (kliniğe özel yüzdelerle).
  List<ProcedureType> get procedures => List.unmodifiable(
      _procedures.where((p) => p.clinicId == _activeClinicId));

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
      clinicId: _activeClinicId,
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
  /// Aktif kliniğin işlemleri.
  List<Treatment> get treatments => List.unmodifiable(_active);
  int get treatmentCount => _active.length;
  bool get hasTreatments => _active.isNotEmpty;

  /// Hastanın işlemleri (tarihe göre azalan), önceden indekslenmiş — O(1).
  List<Treatment> treatmentsForPatient(String patientId) =>
      _byPatient[patientId] ?? const <Treatment>[];

  String newTreatmentId() => _uuid.v4();

  Future<void> saveTreatment(Treatment treatment) async {
    // Klinik bilgisi yoksa aktif kliniğe bağla.
    final t = treatment.clinicId.isEmpty
        ? treatment.copyWith(clinicId: _activeClinicId)
        : treatment;
    await _repo.saveTreatment(t);
    final i = _treatments.indexWhere((x) => x.id == t.id);
    if (i == -1) {
      _treatments.add(t);
    } else {
      _treatments[i] = t;
    }
    _rebuildIndexes();
    notifyListeners();
  }

  Future<void> deleteTreatment(String id) async {
    await _repo.deleteTreatment(id);
    _treatments.removeWhere((t) => t.id == id);
    _rebuildIndexes();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // İÇE AKTARMA (Excel'den — dışa aktarma ile aynı format)
  // ---------------------------------------------------------------------------
  static final _importDateFmt = DateFormat('d MMMM yyyy', 'tr_TR');
  static final _importTimeFmt = DateFormat('HH:mm');

  static double _num(String s) {
    if (s.isEmpty) return 0;
    final a = double.tryParse(s);
    if (a != null) return a;
    final b = double.tryParse(s.replaceAll('.', '').replaceAll(',', '.'));
    return b ?? 0;
  }

  /// Excel'den okunan ham satırları hasta+işlem kayıtlarına dönüştürür.
  /// Aynı isim+telefondaki hasta tekrar oluşturulmaz. (patients, treatments,
  /// skipped) sayılarını döner.
  Future<({int patients, int treatments, int skipped})> importRows(
      List<List<String>> rows) async {
    if (rows.isEmpty) return (patients: 0, treatments: 0, skipped: 0);

    var start = 0;
    if (rows.first.isNotEmpty &&
        rows.first.first.toLowerCase().startsWith('tarih')) {
      start = 1;
    }

    String keyOf(String n, String p) =>
        '${n.toLowerCase().trim()}|${p.trim()}';
    final existing = <String, Patient>{};
    for (final p in _patients) {
      existing[keyOf(p.name, p.phone)] = p;
    }

    var newPatients = 0, newTreatments = 0, skipped = 0;

    for (var i = start; i < rows.length; i++) {
      final r = rows[i];
      String cell(int idx) => idx < r.length ? r[idx] : '';

      final name = cell(2).trim();
      if (name.isEmpty || name == '-') {
        skipped++;
        continue;
      }
      final phone = cell(3).trim();

      DateTime? date;
      try {
        final d = _importDateFmt.parse(cell(0));
        int hh = 0, mm = 0;
        try {
          final tm = _importTimeFmt.parse(cell(1));
          hh = tm.hour;
          mm = tm.minute;
        } catch (_) {}
        date = DateTime(d.year, d.month, d.day, hh, mm);
      } catch (_) {
        date = null;
      }
      if (date == null) {
        skipped++;
        continue;
      }

      final k = keyOf(name, phone);
      var patient = existing[k];
      if (patient == null) {
        patient = Patient(
          id: _uuid.v4(),
          name: name,
          phone: phone,
          note: '',
          createdAt: DateTime.now(),
        );
        await _repo.savePatient(patient);
        _patients.add(patient);
        existing[k] = patient;
        newPatients++;
      }

      final procName = cell(4).trim().isEmpty ? 'İşlem' : cell(4).trim();
      final matched = _procedures.firstWhere(
        (p) => p.name.toLowerCase() == procName.toLowerCase(),
        orElse: () => ProcedureCatalog.manual,
      );
      final total = _num(cell(6));
      final collected = _num(cell(7));
      final doctorShare = _num(cell(9));
      final clinicShare =
          cell(10).isNotEmpty ? _num(cell(10)) : (total - doctorShare);
      final installments = int.tryParse(cell(11)) ?? 1;
      final doctorPaid = cell(13).toLowerCase() == 'evet';
      final teeth = cell(5)
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final t = Treatment(
        id: _uuid.v4(),
        patientId: patient.id,
        clinicId: _activeClinicId,
        procedureId: matched.id,
        procedureName: procName,
        model: matched.model,
        teeth: teeth,
        totalPrice: total,
        labFee: 0,
        percentage: matched.percentage,
        netAmount: matched.netAmount,
        doctorShare: doctorShare,
        clinicShare: clinicShare < 0 ? 0 : clinicShare,
        appointmentDate: date,
        note: cell(14),
        installmentCount: installments < 1 ? 1 : installments,
        collectedAmount: collected.clamp(0, total).toDouble(),
        doctorPaid: doctorPaid,
        createdAt: DateTime.now(),
      );
      await _repo.saveTreatment(t);
      _treatments.add(t);
      newTreatments++;
    }

    _patients.sort(_patientSort);
    _rebuildIndexes();
    notifyListeners();
    return (
      patients: newPatients,
      treatments: newTreatments,
      skipped: skipped
    );
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
    // Klinik tahsilatı sıfırlanırsa doktor payı da alınamamış sayılır.
    await updatePayment(t,
        collectedAmount: collected,
        doctorPaid: collected <= 0 ? false : t.doctorPaid);
  }

  /// Doktor payı alındı durumunu değiştirir.
  Future<void> toggleDoctorPaid(Treatment t) async {
    if (!t.clinicCollected) return;
    await updatePayment(t, doctorPaid: !t.doctorPaid);
  }

  // --- Hasta bazlı toplamlar (indeksten, O(1)) ---
  double patientTotal(String patientId) => _agg[patientId]?.total ?? 0;
  double patientOutstanding(String patientId) =>
      _agg[patientId]?.outstanding ?? 0;
  int patientTreatmentCount(String patientId) => _agg[patientId]?.count ?? 0;

  /// Bu hasta için klinik tahsil etti ama doktor payı henüz alınmadıysa toplam.
  double patientAwaitingPayout(String patientId) =>
      _agg[patientId]?.awaitingPayout ?? 0;

  // ---------------------------------------------------------------------------
  // RANDEVULAR / TAKVİM
  // ---------------------------------------------------------------------------
  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<Treatment> appointmentsOn(DateTime day) {
    final list =
        _active.where((t) => _sameDay(t.appointmentDate, day)).toList();
    list.sort((a, b) => a.appointmentDate.compareTo(b.appointmentDate));
    return list;
  }

  List<Treatment> get todaysAppointments => appointmentsOn(DateTime.now());

  /// Bir ay içindeki her gün için randevu sayısı (takvim noktaları için).
  Map<int, int> appointmentCountsByDay(DateTime month) {
    final map = <int, int>{};
    for (final t in _active) {
      final d = t.appointmentDate;
      if (d.year == month.year && d.month == month.month) {
        map[d.day] = (map[d.day] ?? 0) + 1;
      }
    }
    return map;
  }

  // ---------------------------------------------------------------------------
  // DOKTOR PAYI BEKLEYENLER (klinik tahsil etti, doktor almadı) — indeksli
  // ---------------------------------------------------------------------------
  List<Treatment> get awaitingDoctorPayout => _awaiting;
  double get awaitingDoctorPayoutTotal => _awaitingTotal;

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
    return _active
        .where((t) => _inRange(t.appointmentDate, ref, range))
        .toList()
      ..sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));
  }

  /// İstatistik + kırılım tek geçişte hesaplanır (büyük veri için verimli).
  ({PeriodStats stats, Map<String, ({int count, double total, double doctor})> breakdown})
      periodReport(DateTime ref, StatsRange range) {
    double total = 0,
        doctor = 0,
        clinic = 0,
        collected = 0,
        outstanding = 0,
        doctorPaid = 0,
        doctorPending = 0;
    final patientIds = <String>{};
    final breakdown = <String, ({int count, double total, double doctor})>{};
    var count = 0;

    for (final t in _active) {
      if (!_inRange(t.appointmentDate, ref, range)) continue;
      count++;
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
      final prev =
          breakdown[t.procedureName] ?? (count: 0, total: 0.0, doctor: 0.0);
      breakdown[t.procedureName] = (
        count: prev.count + 1,
        total: prev.total + t.totalPrice,
        doctor: prev.doctor + t.doctorShare,
      );
    }

    return (
      stats: PeriodStats(
        total: total,
        doctor: doctor,
        clinic: clinic,
        collected: collected,
        outstanding: outstanding,
        doctorPaid: doctorPaid,
        doctorPending: doctorPending,
        procedureCount: count,
        patientCount: patientIds.length,
      ),
      breakdown: breakdown,
    );
  }

  PeriodStats statsFor(DateTime ref, StatsRange range) =>
      periodReport(ref, range).stats;

  /// İşlem türüne göre kırılım (istatistik ekranı için).
  Map<String, ({int count, double total, double doctor})> breakdownByProcedure(
          DateTime ref, StatsRange range) =>
      periodReport(ref, range).breakdown;
}

/// Türkçe alfabe sırasına yakın, harf-büyüklüğü duyarsız karşılaştırıcı.
class _TrCollator {
  static const _order = 'aâbcçdefgğhıiîjklmnoöprsştuüvyz0123456789';
  int _rank(String ch) {
    final i = _order.indexOf(ch);
    return i < 0 ? _order.length + ch.codeUnitAt(0) : i;
  }

  int compare(String a, String b) {
    final x = a.toLowerCase().trim();
    final y = b.toLowerCase().trim();
    final n = x.length < y.length ? x.length : y.length;
    for (var i = 0; i < n; i++) {
      final d = _rank(x[i]) - _rank(y[i]);
      if (d != 0) return d;
    }
    return x.length - y.length;
  }
}
