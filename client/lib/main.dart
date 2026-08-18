import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:momen_pair_client/app/app.dart';
import 'package:momen_pair_client/core/config/app_config.dart';
import 'package:momen_pair_client/core/network/api_client.dart';
import 'package:momen_pair_client/core/storage/session_store.dart';
import 'package:momen_pair_client/features/auth/data/http_auth_repository.dart';
import 'package:momen_pair_client/features/auth/presentation/session_controller.dart';
import 'package:momen_pair_client/features/families/data/http_family_repository.dart';
import 'package:momen_pair_client/features/families/presentation/family_controller.dart';
import 'package:momen_pair_client/features/logs/data/http_log_repository.dart';
import 'package:momen_pair_client/features/logs/presentation/log_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  final apiClient = ApiClient(baseUri: config.apiBaseUri);
  final repository = HttpAuthRepository(
    apiClient: apiClient,
    store: SecureSessionStore(),
  );
  final sessionController = SessionController(repository: repository);
  final familyController = FamilyController(
    repository: HttpFamilyRepository(apiClient: apiClient),
    sessionController: sessionController,
  );
  final logController = LogController(
    repository: HttpLogRepository(apiClient: apiClient),
    sessionController: sessionController,
    familyController: familyController,
    apiBaseUri: config.apiBaseUri,
  );
  runApp(
    MomenPairApp(
      sessionController: sessionController,
      familyController: familyController,
      logController: logController,
      enableFakeSocialLogin: config.enableFakeSocialLogin,
    ),
  );
  unawaited(sessionController.restore());
}
