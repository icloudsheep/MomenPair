import 'package:flutter/foundation.dart';
import 'package:momen_pair_client/core/network/api_client.dart';
import 'package:momen_pair_client/features/auth/domain/auth_models.dart';
import 'package:momen_pair_client/features/auth/domain/auth_repository.dart';

enum SessionStatus { loading, authenticated, unauthenticated }

class SessionController extends ChangeNotifier {
  SessionController({
    required AuthRepository repository,
    AuthSession? initialSession,
  }) : _repository = repository,
       _session = initialSession,
       _status = initialSession == null
           ? SessionStatus.loading
           : SessionStatus.authenticated;

  final AuthRepository _repository;
  AuthSession? _session;
  SessionStatus _status;
  String? _errorCode;

  SessionStatus get status => _status;
  AuthSession? get session => _session;
  String? get errorCode => _errorCode;

  Future<void> restore() async {
    if (_session != null) {
      return;
    }
    try {
      _session = await _repository.restore();
      _status = _session == null
          ? SessionStatus.unauthenticated
          : SessionStatus.authenticated;
    } on Object {
      _status = SessionStatus.unauthenticated;
      _errorCode = 'service_unavailable';
    }
    notifyListeners();
  }

  Future<void> loginWithCode(SocialProvider provider, String code) async {
    if (_status == SessionStatus.loading) {
      return;
    }
    _status = SessionStatus.loading;
    _errorCode = null;
    notifyListeners();
    try {
      _session = await _repository.loginWithCode(provider, code);
      _status = SessionStatus.authenticated;
    } on ApiException catch (error) {
      _status = SessionStatus.unauthenticated;
      _errorCode = error.code;
    } on Object {
      _status = SessionStatus.unauthenticated;
      _errorCode = 'service_unavailable';
    }
    notifyListeners();
  }

  Future<void> logout() async {
    _status = SessionStatus.loading;
    notifyListeners();
    try {
      await _repository.logout();
    } finally {
      _session = null;
      _status = SessionStatus.unauthenticated;
      notifyListeners();
    }
  }
}
