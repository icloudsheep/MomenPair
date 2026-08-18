import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:momen_pair_client/features/auth/domain/auth_models.dart';
import 'package:momen_pair_client/features/auth/presentation/session_scope.dart';
import 'package:momen_pair_client/features/families/domain/family_models.dart';
import 'package:momen_pair_client/features/families/presentation/family_controller.dart';
import 'package:momen_pair_client/features/families/presentation/family_scope.dart';
import 'package:momen_pair_client/l10n/generated/app_localizations.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _familyNameController = TextEditingController();
  final _invitationCodeController = TextEditingController();
  bool _syncScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_syncScheduled) {
      return;
    }
    _syncScheduled = true;
    final familyController = FamilyScope.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        familyController.sync();
      }
    });
  }

  @override
  void dispose() {
    _familyNameController.dispose();
    _invitationCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return CustomScrollView(
      key: const PageStorageKey('profile'),
      slivers: [
        SliverAppBar.large(title: Text(l10n.profileTitle)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          sliver: SliverList.list(
            children: [
              _buildAccountCard(context),
              const SizedBox(height: 16),
              _buildFamilyCard(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = SessionScope.of(context);
    final user = controller.session!.user;
    final providerName = switch (user.provider) {
      SocialProvider.wechat => l10n.wechatProvider,
      SocialProvider.qq => l10n.qqProvider,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 32,
              child: Text(user.displayName.characters.first),
            ),
            const SizedBox(height: 16),
            Text(
              user.displayName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.verified_user_outlined),
              title: Text(l10n.currentLoginProvider),
              subtitle: Text(providerName),
            ),
            Text(
              l10n.independentAccountNotice,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: controller.logout,
              icon: const Icon(Icons.logout),
              label: Text(l10n.logout),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = FamilyScope.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.family_restroom),
                const SizedBox(width: 12),
                Text(
                  l10n.familySpace,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 20),
            switch (controller.status) {
              FamilyStatus.idle || FamilyStatus.loading => const Center(
                child: CircularProgressIndicator(),
              ),
              FamilyStatus.noFamily => _buildNoFamily(context, controller),
              FamilyStatus.ready => _buildCurrentFamily(context, controller),
              FamilyStatus.error => _buildFamilyError(context, controller),
            },
            if (controller.busy) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
            if (controller.errorCode != null &&
                controller.status != FamilyStatus.error) ...[
              const SizedBox(height: 12),
              Text(
                l10n.familyOperationFailed,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoFamily(BuildContext context, FamilyController controller) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.noFamilyDescription),
        const SizedBox(height: 16),
        TextField(
          controller: _familyNameController,
          enabled: !controller.busy,
          maxLength: 80,
          decoration: InputDecoration(
            labelText: l10n.familyName,
            border: const OutlineInputBorder(),
          ),
        ),
        FilledButton.icon(
          onPressed: controller.busy
              ? null
              : () => controller.create(_familyNameController.text),
          icon: const Icon(Icons.add_home_outlined),
          label: Text(l10n.createFamily),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Divider(),
        ),
        TextField(
          controller: _invitationCodeController,
          enabled: !controller.busy,
          decoration: InputDecoration(
            labelText: l10n.invitationCode,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: controller.busy
              ? null
              : () => controller.join(_invitationCodeController.text),
          icon: const Icon(Icons.group_add_outlined),
          label: Text(l10n.joinFamily),
        ),
      ],
    );
  }

  Widget _buildCurrentFamily(
    BuildContext context,
    FamilyController controller,
  ) {
    final l10n = AppLocalizations.of(context);
    final family = controller.family!;
    final isAdmin = family.role == FamilyRole.admin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(family.name, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          '${_roleName(l10n, family.role)} · '
          '${l10n.familyMemberCount(family.memberCount)}',
        ),
        if (isAdmin) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: controller.busy
                ? null
                : () => _createInvitation(context, controller),
            icon: const Icon(Icons.person_add_alt_1),
            label: Text(l10n.createInvitation),
          ),
          if (controller.invitations.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              l10n.activeInvitations,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final invitation in controller.invitations)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.key_outlined),
                title: Text(_invitationStatusName(l10n, invitation.status)),
                subtitle: Text(
                  l10n.invitationUsage(
                    invitation.usedCount,
                    invitation.maxUses,
                  ),
                ),
                trailing: invitation.status == 'active'
                    ? IconButton(
                        onPressed: controller.busy
                            ? null
                            : () => controller.revokeInvitation(invitation.id),
                        tooltip: l10n.revoke,
                        icon: const Icon(Icons.block),
                      )
                    : null,
              ),
          ],
        ],
        const SizedBox(height: 20),
        Text(
          l10n.familyMembers,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final member in controller.members)
          _buildMemberTile(context, controller, member, isAdmin),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: controller.busy
              ? null
              : () => _confirmLeave(context, controller),
          icon: const Icon(Icons.exit_to_app),
          label: Text(l10n.leaveFamily),
        ),
      ],
    );
  }

  Widget _buildMemberTile(
    BuildContext context,
    FamilyController controller,
    FamilyMember member,
    bool currentUserIsAdmin,
  ) {
    final l10n = AppLocalizations.of(context);
    final currentUserId = SessionScope.of(context).session!.user.id;
    final canManage = currentUserIsAdmin && member.userId != currentUserId;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Text(member.displayName.characters.first)),
      title: Text(
        member.userId == currentUserId
            ? '${member.displayName} (${l10n.youLabel})'
            : member.displayName,
      ),
      subtitle: Text(_roleName(l10n, member.role)),
      trailing: canManage
          ? PopupMenuButton<_MemberAction>(
              enabled: !controller.busy,
              onSelected: (action) =>
                  _handleMemberAction(controller, member, action),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: member.role == FamilyRole.admin
                      ? _MemberAction.makeMember
                      : _MemberAction.makeAdmin,
                  child: Text(
                    member.role == FamilyRole.admin
                        ? l10n.makeMember
                        : l10n.makeAdmin,
                  ),
                ),
                PopupMenuItem(
                  value: _MemberAction.remove,
                  child: Text(l10n.removeMember),
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildFamilyError(BuildContext context, FamilyController controller) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Text(
          l10n.familyOperationFailed,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: controller.load, child: Text(l10n.retry)),
      ],
    );
  }

  Future<void> _createInvitation(
    BuildContext context,
    FamilyController controller,
  ) async {
    final code = await controller.createInvitation();
    if (!context.mounted || code == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.inviteCodeTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.inviteCodeDescription),
            const SizedBox(height: 16),
            SelectableText(code),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Clipboard.setData(ClipboardData(text: code)),
            icon: const Icon(Icons.copy),
            label: Text(l10n.copy),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLeave(
    BuildContext context,
    FamilyController controller,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.leaveFamilyConfirmTitle),
        content: Text(l10n.leaveFamilyConfirmDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await controller.leave();
    }
  }

  Future<void> _handleMemberAction(
    FamilyController controller,
    FamilyMember member,
    _MemberAction action,
  ) async {
    switch (action) {
      case _MemberAction.makeAdmin:
        await controller.changeRole(member.userId, FamilyRole.admin);
      case _MemberAction.makeMember:
        await controller.changeRole(member.userId, FamilyRole.member);
      case _MemberAction.remove:
        await controller.removeMember(member.userId);
    }
  }

  String _roleName(AppLocalizations l10n, FamilyRole role) => switch (role) {
    FamilyRole.admin => l10n.familyAdmin,
    FamilyRole.member => l10n.familyMember,
  };

  String _invitationStatusName(AppLocalizations l10n, String status) =>
      switch (status) {
        'active' => l10n.invitationActive,
        'exhausted' => l10n.invitationExhausted,
        'expired' => l10n.invitationExpired,
        'revoked' => l10n.invitationRevoked,
        _ => status,
      };
}

enum _MemberAction { makeAdmin, makeMember, remove }
