import '../local/hive_boxes.dart';
import '../local/photo_storage.dart';
import '../models/patient.dart';
import '../models/procedure_type.dart';
import '../models/treatment.dart';

/// Hasta ve işlem verilerinin yerel veritabanı (Hive) üzerinden yönetimi.
///
/// Sunum katmanı doğrudan Hive'ı değil bu repository'yi kullanır.
class ClinicRepository {
  // --- Hastalar ---
  List<Patient> getPatients() {
    return HiveBoxes.patientsBox.values
        .map((e) => Patient.fromMap(Map<dynamic, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> savePatient(Patient patient) async {
    await HiveBoxes.patientsBox.put(patient.id, patient.toMap());
  }

  Future<void> deletePatient(String patientId) async {
    await HiveBoxes.patientsBox.delete(patientId);
    // Hastaya ait işlemleri ve onların fotoğraf dosyalarını da temizle.
    final owned =
        getTreatments().where((t) => t.patientId == patientId).toList();
    for (final t in owned) {
      await _deletePhotos(t);
      await HiveBoxes.treatmentsBox.delete(t.id);
    }
  }

  // --- İşlemler ---
  List<Treatment> getTreatments() {
    return HiveBoxes.treatmentsBox.values
        .map((e) => Treatment.fromMap(Map<dynamic, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> saveTreatment(Treatment treatment) async {
    await HiveBoxes.treatmentsBox.put(treatment.id, treatment.toMap());
  }

  Future<void> deleteTreatment(String treatmentId) async {
    final raw = HiveBoxes.treatmentsBox.get(treatmentId);
    if (raw != null) {
      await _deletePhotos(
          Treatment.fromMap(Map<dynamic, dynamic>.from(raw as Map)));
    }
    await HiveBoxes.treatmentsBox.delete(treatmentId);
  }

  /// Bir işlemin diskteki fotoğraf dosyalarını siler (öksüz dosya bırakmaz).
  Future<void> _deletePhotos(Treatment t) async {
    for (final path in t.photos) {
      await PhotoStorage.delete(path);
    }
  }

  // --- İşlem tanımları (katalog) ---
  List<ProcedureType> getProcedures() {
    return HiveBoxes.proceduresBox.values
        .map((e) => ProcedureType.fromMap(Map<dynamic, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> saveProcedure(ProcedureType procedure) async {
    await HiveBoxes.proceduresBox.put(procedure.id, procedure.toMap());
  }

  Future<void> deleteProcedure(String procedureId) async {
    await HiveBoxes.proceduresBox.delete(procedureId);
  }

  // --- Ayarlar (meta_box) ---
  T? getSetting<T>(String key) => HiveBoxes.metaBox.get(key) as T?;

  Future<void> setSetting(String key, dynamic value) async {
    await HiveBoxes.metaBox.put(key, value);
  }
}
