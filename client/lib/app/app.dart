import 'package:flutter/material.dart';
import 'package:momen_pair_client/app/theme/app_theme.dart';
import 'package:momen_pair_client/features/auth/presentation/session_controller.dart';
import 'package:momen_pair_client/features/auth/presentation/session_gate.dart';
import 'package:momen_pair_client/features/auth/presentation/session_scope.dart';
import 'package:momen_pair_client/l10n/generated/app_localizations.dart';

class MomenPairApp extends StatelessWidget {
  const MomenPairApp({
    required this.sessionController,
    required this.enableFakeSocialLogin,
    this.locale,
    super.key,
  });

  final SessionController sessionController;
  final bool enableFakeSocialLogin;
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: SessionScope(
        controller: sessionController,
        child: SessionGate(enableFakeSocialLogin: enableFakeSocialLogin),
      ),
    );
  }
}
