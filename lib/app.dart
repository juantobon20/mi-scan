import 'package:flutter/material.dart';

import 'core/di/service_locator.dart';
import 'core/l10n/l10n.dart';
import 'core/theme/app_theme.dart';
import 'presentation/home/home_controller.dart';
import 'presentation/home/home_screen.dart';
import 'presentation/navigation/screen_factory.dart';
import 'presentation/scanner/scan_session.dart';

class MiScanApp extends StatelessWidget {
  const MiScanApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        onGenerateTitle: (context) => context.l10n.appName,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: HomeScreen(
          controller: sl<HomeController>(),
          startSession: sl<ScanSessionFactory>(),
          factory: sl<ScreenFactory>(),
        ),
      );
}
