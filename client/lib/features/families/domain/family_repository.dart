import 'package:momen_pair_client/features/families/domain/family_models.dart';

abstract interface class FamilyRepository {
  Future<FamilySummary> getCurrent(String accessToken);

  Future<FamilySummary> create(String accessToken, String name);

  Future<FamilySummary> join(String accessToken, String code);

  Future<List<FamilyMember>> getMembers(String accessToken);

  Future<List<FamilyInvitation>> getInvitations(String accessToken);

  Future<CreatedFamilyInvitation> createInvitation(String accessToken);

  Future<void> revokeInvitation(String accessToken, String invitationId);

  Future<FamilyMember> changeMemberRole(
    String accessToken,
    String userId,
    FamilyRole role,
  );

  Future<void> removeMember(String accessToken, String userId);

  Future<void> leave(String accessToken);
}
