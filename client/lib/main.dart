import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:momen_pair_client/app/app.dart';
import 'package:momen_pair_client/core/config/app_config.dart';
import 'package:momen_pair_client/core/network/api_client.dart';
import 'package:momen_pair_client/core/storage/session_store.dart';
import 'package:momen_pair_client/features/auth/data/http_auth_repository.dart';
import 'package:momen_pair_client/features/auth/presentation/session_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  final apiClient = ApiClient(baseUri: config.apiBaseUri);
  final repository = HttpAuthRepository(
    apiClient: apiClient,
    store: SecureSessionStore(),
  );
  final sessionController = SessionController(repository: repository);
  runApp(
    MomenPairApp(
      sessionController: sessionController,
      enableFakeSocialLogin: config.enableFakeSocialLogin,
    ),
  );
  unawaited(sessionController.restore());
}
