import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'data/local/hive_boxes.dart';
import 'data/repositories/clinic_repository.dart';
import 'presentation/providers/clinic_provider.dart';
import 'presentation/screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null);
  await HiveBoxes.init();

  runApp(const OzgurDentApp());
}

class OzgurDentApp extends StatelessWidget {
  const OzgurDentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ClinicProvider(ClinicRepository())..load(),
      child: MaterialApp(
        title: 'ÖzgürDent',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: const Locale('tr', 'TR'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('tr', 'TR')],
        home: const HomeShell(),
      ),
    );
  }
}
