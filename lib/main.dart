import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'data/local/hive_boxes.dart';
import 'data/local/notification_service.dart';
import 'data/repositories/clinic_repository.dart';
import 'presentation/providers/clinic_provider.dart';
import 'presentation/providers/notification_controller.dart';
import 'presentation/providers/theme_controller.dart';
import 'presentation/screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null);
  await HiveBoxes.init();
  await NotificationService.init();

  final repo = ClinicRepository();
  final clinic = ClinicProvider(repo);
  await clinic.load();
  final theme = ThemeController(repo);
  final notif = NotificationController(repo);
  // Uygulama açılışında günlük randevu bildirimlerini tazele.
  if (notif.enabled) {
    await notif.reschedule(clinic);
  }

  runApp(OzgurDentApp(clinic: clinic, theme: theme, notif: notif));
}

class OzgurDentApp extends StatelessWidget {
  final ClinicProvider clinic;
  final ThemeController theme;
  final NotificationController notif;

  const OzgurDentApp({
    super.key,
    required this.clinic,
    required this.theme,
    required this.notif,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: clinic),
        ChangeNotifierProvider.value(value: theme),
        ChangeNotifierProvider.value(value: notif),
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
