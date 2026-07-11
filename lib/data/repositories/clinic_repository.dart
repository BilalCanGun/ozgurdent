import '../local/hive_boxes.dart';
import '../models/patient.dart';
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
    // Hastaya ait işlemleri de temizle.
    final ids = getTreatments()
        .where((t) => t.patientId == patientId)
        .map((t) => t.id)
        .toList();
    for (final id in ids) {
      await HiveBoxes.treatmentsBox.delete(id);
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
    await HiveBoxes.treatmentsBox.delete(treatmentId);
  }
}
