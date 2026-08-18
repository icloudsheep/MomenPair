import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:momen_pair_client/core/network/api_client.dart';
import 'package:momen_pair_client/features/auth/presentation/session_controller.dart';
import 'package:momen_pair_client/features/families/domain/family_models.dart';
import 'package:momen_pair_client/features/families/domain/family_repository.dart';

enum FamilyStatus { idle, loading, noFamily, ready, error }

class FamilyController extends ChangeNotifier {
  FamilyController({
    required FamilyRepository repository,
    required SessionController sessionController,
  })  : _repository = repository,
        _sessionController = sessionController {
    _sessionController.addListener(_handleSessionChange);
  }

  final FamilyRepository _repository;
  final SessionController _sessionController;

  FamilyStatus _status = FamilyStatus.idle;
  FamilySummary? _family;
  List<FamilyMember> _members = const [];
  List<FamilyInvitation> _invitations = const [];
  String? _errorCode;
  String? _userId;
  bool _busy = false;

  FamilyStatus get status => _status;
  FamilySummary? get family => _family;
  List<FamilyMember> get members => _members;
  List<FamilyInvitation> get invitations => _invitations;
  String? get errorCode => _errorCode;
  bool get busy => _busy;

  void sync() {
    final userId = _sessionController.session?.user.id;
    if (userId == null || userId == _userId) {
      return;
    }
    _userId = userId;
    unawaited(load());
  }

  Future<void> load() async {
    final session = _sessionController.session;
    if (session == null) {
      _reset();
      notifyListeners();
      return;
    }
    final requestedUserId = session.user.id;
    _status = FamilyStatus.loading;
    _errorCode = null;
    notifyListeners();
    try {
      final family = await _repository.getCurrent(session.accessToken);
      final members = await _repository.getMembers(session.accessToken);
      final invitations = family.role == FamilyRole.admin
          ? await _repository.getInvitations(session.accessToken)
          : const <FamilyInvitation>[];
      if (_sessionController.session?.user.id != requestedUserId) {
        return;
      }
      _family = family;
      _members = members;
      _invitations = invitations;
      _status = FamilyStatus.ready;
    } on ApiException catch (error) {
      if (error.code == 'family_not_found') {
        _family = null;
        _members = const [];
        _invitations = const [];
        _status = FamilyStatus.noFamily;
      } else {
        _status = FamilyStatus.error;
        _errorCode = error.code;
      }
    } on Object {
      _status = FamilyStatus.error;
      _errorCode = 'service_unavailable';
    }
    notifyListeners();
  }

  Future<void> create(String name) async {
    if (name.trim().isEmpty) {
      _errorCode = 'family_name_required';
      notifyListeners();
      return;
    }
    await _replaceFamily(
      (token) => _repository.create(token, name.trim()),
    );
  }

  Future<void> join(String code) async {
    if (code.trim().isEmpty) {
      _errorCode = 'invitation_invalid';
      notifyListeners();
      return;
    }
    await _replaceFamily(
      (token) => _repository.join(token, code.trim()),
    );
  }

  Future<String?> createInvitation() async {
    final token = _accessToken;
    if (token == null || _busy) {
      return null;
    }
    _startAction();
    try {
      final created = await _repository.createInvitation(token);
      try {
        _invitations = await _repository.getInvitations(token);
      } on ApiException catch (error) {
        _errorCode = error.code;
      } on Object {
        _errorCode = 'service_unavailable';
      }
      return created.code;
    } on ApiException catch (error) {
      _errorCode = error.code;
      return null;
    } on Object {
      _errorCode = 'service_unavailable';
      return null;
    } finally {
      _finishAction();
    }
  }

  Future<void> revokeInvitation(String invitationId) async {
    await _runAction((token) async {
      await _repository.revokeInvitation(token, invitationId);
      _invitations = await _repository.getInvitations(token);
    });
  }

  Future<void> changeRole(String userId, FamilyRole role) async {
    await _runAction((token) async {
      await _repository.changeMemberRole(token, userId, role);
      await _reloadFamilyData(token);
    });
  }

  Future<void> removeMember(String userId) async {
    await _runAction((token) async {
      await _repository.removeMember(token, userId);
      await _reloadFamilyData(token);
    });
  }

  Future<void> leave() async {
    final token = _accessToken;
    if (token == null || _busy) {
      return;
    }
    _startAction();
    try {
      await _repository.leave(token);
      _family = null;
      _members = const [];
      _invitations = const [];
      _status = FamilyStatus.noFamily;
    } on ApiException catch (error) {
      _errorCode = error.code;
    } on Object {
      _errorCode = 'service_unavailable';
    } finally {
      _finishAction();
    }
  }

  Future<void> _replaceFamily(
    Future<FamilySummary> Function(String token) operation,
  ) async {
    final token = _accessToken;
    if (token == null || _busy) {
      return;
    }
    _startAction();
    try {
      _family = await operation(token);
      _status = FamilyStatus.ready;
      await _reloadFamilyData(token);
    } on ApiException catch (error) {
      _errorCode = error.code;
    } on Object {
      _errorCode = 'service_unavailable';
    } finally {
      _finishAction();
    }
  }

  Future<void> _runAction(
    Future<void> Function(String token) operation,
  ) async {
    final token = _accessToken;
    if (token == null || _busy) {
      return;
    }
    _startAction();
    try {
      await operation(token);
    } on ApiException catch (error) {
      _errorCode = error.code;
    } on Object {
      _errorCode = 'service_unavailable';
    } finally {
      _finishAction();
    }
  }

  Future<void> _reloadFamilyData(String token) async {
    final family = await _repository.getCurrent(token);
    _family = family;
    _members = await _repository.getMembers(token);
    _invitations = family.role == FamilyRole.admin
        ? await _repository.getInvitations(token)
        : const [];
  }

  void _startAction() {
    _busy = true;
    _errorCode = null;
    notifyListeners();
  }

  void _finishAction() {
    _busy = false;
    notifyListeners();
  }

  String? get _accessToken => _sessionController.session?.accessToken;

  void _handleSessionChange() {
    if (_sessionController.session == null && _userId != null) {
      _reset();
      notifyListeners();
    }
  }

  void _reset() {
    _userId = null;
    _family = null;
    _members = const [];
    _invitations = const [];
    _errorCode = null;
    _busy = false;
    _status = FamilyStatus.idle;
  }

  @override
  void dispose() {
    _sessionController.removeListener(_handleSessionChange);
    super.dispose();
  }
}
