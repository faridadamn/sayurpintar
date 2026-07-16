import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sayurpintar/app/router.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/core/utils/locale_provider.dart';

// TODO: Replace with generated AppLocalizations once l10n is configured
// import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SayurPintarApp extends ConsumerWidget {
  const SayurPintarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'SayurPintar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      routerConfig: appRouter,
      locale: locale,
      localizationsDelegates: const [
        // AppLocalizations.delegate, // Uncomment when l10n codegen is set up
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('id'), // Indonesian
        Locale('jv'), // Javanese
        Locale('su'), // Sundanese
      ],
    );
  }
}
