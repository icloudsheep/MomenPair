import 'package:momen_pair_client/core/network/api_client.dart';
import 'package:momen_pair_client/features/families/domain/family_models.dart';
import 'package:momen_pair_client/features/families/domain/family_repository.dart';

class HttpFamilyRepository implements FamilyRepository {
  const HttpFamilyRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<FamilySummary> getCurrent(String accessToken) async {
    final json = await _apiClient.get(
      'families/current',
      accessToken: accessToken,
    );
    return FamilySummary.fromJson(json);
  }

  @override
  Future<FamilySummary> create(String accessToken, String name) async {
    final json = await _apiClient.post(
      'families',
      body: {'name': name},
      accessToken: accessToken,
    );
    return FamilySummary.fromJson(json);
  }

  @override
  Future<FamilySummary> join(String accessToken, String code) async {
    final json = await _apiClient.post(
      'families/join',
      body: {'code': code},
      accessToken: accessToken,
    );
    return FamilySummary.fromJson(json);
  }

  @override
  Future<List<FamilyMember>> getMembers(String accessToken) async {
    final json = await _apiClient.getList(
      'families/current/members',
      accessToken: accessToken,
    );
    return json.map(FamilyMember.fromJson).toList(growable: false);
  }

  @override
  Future<List<FamilyInvitation>> getInvitations(String accessToken) async {
    final json = await _apiClient.getList(
      'families/current/invitations',
      accessToken: accessToken,
    );
    return json.map(FamilyInvitation.fromJson).toList(growable: false);
  }

  @override
  Future<CreatedFamilyInvitation> createInvitation(
    String accessToken,
  ) async {
    final json = await _apiClient.post(
      'families/current/invitations',
      body: const {'expires_in_hours': 24, 'max_uses': 1},
      accessToken: accessToken,
    );
    return CreatedFamilyInvitation.fromJson(json);
  }

  @override
  Future<void> revokeInvitation(
    String accessToken,
    String invitationId,
  ) async {
    await _apiClient.delete(
      'families/current/invitations/$invitationId',
      accessToken: accessToken,
    );
  }

  @override
  Future<FamilyMember> changeMemberRole(
    String accessToken,
    String userId,
    FamilyRole role,
  ) async {
    final json = await _apiClient.patch(
      'families/current/members/$userId',
      body: {'role': role.name},
      accessToken: accessToken,
    );
    return FamilyMember.fromJson(json);
  }

  @override
  Future<void> removeMember(String accessToken, String userId) async {
    await _apiClient.delete(
      'families/current/members/$userId',
      accessToken: accessToken,
    );
  }

  @override
  Future<void> leave(String accessToken) async {
    await _apiClient.post(
      'families/current/leave',
      body: const {},
      accessToken: accessToken,
    );
  }
}
