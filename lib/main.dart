// fichier: lib/main.dart

import 'package:colors_notes/app_router.dart';
import 'package:colors_notes/l10n/app_localizations.dart';
import 'package:colors_notes/providers/active_journal_provider.dart';
import 'package:colors_notes/providers/language_provider.dart';
import 'package:colors_notes/services/bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() async {
  // 1. Initialise tous les services en amont.
  final bootstrap = await AppBootstrap.create();

  // 2. Lance l'application en lui passant les services initialisés.
  runApp(MyApp(bootstrap: bootstrap));
}

class MyApp extends StatelessWidget {
  final AppBootstrap bootstrap;

  const MyApp({super.key, required this.bootstrap});

  @override
  Widget build(BuildContext context) {
    // 3. Fournit les services à l'ensemble de l'arbre de widgets.
    return MultiProvider(
      providers: [
        Provider.value(value: bootstrap.authService),
        Provider.value(value: bootstrap.firestoreService),
        ChangeNotifierProvider.value(value: bootstrap.languageProvider),
        ChangeNotifierProvider(
          create: (_) => ActiveJournalNotifier(
            bootstrap.authService,
            bootstrap.firestoreService,
          ),
        ),
      ],
      // Utilise un Consumer pour reconstruire MaterialApp si la langue change.ancestry.com
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Colors & Notes',

            // Configuration de la langue
            locale: languageProvider.appLocale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,

            // Configuration du routage
            onGenerateRoute: AppRouter.generateRoute,
            initialRoute: '/',

            // Thème de l'application
            theme: ThemeData(
              primarySwatch: Colors.teal,
              visualDensity: VisualDensity.adaptivePlatformDensity,
              colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal)
                  .copyWith(secondary: Colors.amberAccent),
            ),
          );
        },
      ),
    );
  }
}
