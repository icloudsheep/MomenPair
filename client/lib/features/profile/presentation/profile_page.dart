import 'package:flutter/material.dart';
import 'package:momen_pair_client/features/auth/domain/auth_models.dart';
import 'package:momen_pair_client/features/auth/presentation/session_scope.dart';
import 'package:momen_pair_client/l10n/generated/app_localizations.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = SessionScope.of(context);
    final user = controller.session!.user;
    final providerName = switch (user.provider) {
      SocialProvider.wechat => l10n.wechatProvider,
      SocialProvider.qq => l10n.qqProvider,
    };
    return CustomScrollView(
      key: const PageStorageKey('profile'),
      slivers: [
        SliverAppBar.large(title: Text(l10n.profileTitle)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          sliver: SliverToBoxAdapter(
            child: Card(
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
            ),
          ),
        ),
      ],
    );
  }
}
