import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'data/local/hive_boxes.dart';
import 'data/repositories/clinic_repository.dart';
import 'presentation/providers/clinic_provider.dart';
import 'presentation/providers/theme_controller.dart';
import 'presentation/screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null);
  await HiveBoxes.init();

  final repo = ClinicRepository();
  runApp(OzgurDentApp(repo: repo));
}

class OzgurDentApp extends StatelessWidget {
  final ClinicRepository repo;
  const OzgurDentApp({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ClinicProvider(repo)..load()),
        ChangeNotifierProvider(create: (_) => ThemeController(repo)),
      ],
      child: Consumer<ThemeController>(
        builder: (context, theme, _) {
          return MaterialApp(
            title: 'ÖzgürDent',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(),
            themeMode: ThemeMode.light,
            locale: const Locale('tr', 'TR'),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('tr', 'TR')],
            // Klavye açıkken boş bir yere dokununca klavyeyi kapat.
            builder: (context, child) {
              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                excludeFromSemantics: true,
                onTap: () {
                  final focus = FocusManager.instance.primaryFocus;
                  if (focus != null && focus.hasFocus) focus.unfocus();
                },
                child: child,
              );
            },
            home: const HomeShell(),
          );
        },
      ),
    );
  }
}
