import 'package:hive_flutter/hive_flutter.dart';

/// Hive kutularının (box) merkezi başlatma noktası.
///
/// Veriler cihazda kalıcı olarak saklanır (localStorage benzeri).
/// Kayıtlar Map olarak tutulur; ayrı bir TypeAdapter üretimine gerek yoktur.
class HiveBoxes {
  HiveBoxes._();

  static const String patients = 'patients_box';
  static const String treatments = 'treatments_box';
  static const String meta = 'meta_box';

  static late Box patientsBox;
  static late Box treatmentsBox;
  static late Box metaBox;

  static Future<void> init() async {
    await Hive.initFlutter();
    patientsBox = await Hive.openBox(patients);
    treatmentsBox = await Hive.openBox(treatments);
    metaBox = await Hive.openBox(meta);
  }
}
