import 'package:flutter/material.dart';
import 'package:momen_pair_client/features/auth/domain/auth_models.dart';
import 'package:momen_pair_client/features/auth/presentation/session_scope.dart';
import 'package:momen_pair_client/l10n/generated/app_localizations.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({required this.enableFakeSocialLogin, super.key});

  final bool enableFakeSocialLogin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = SessionScope.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.family_restroom,
                        size: 52,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.loginTitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.loginDescription,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: enableFakeSocialLogin
                            ? () => _login(context, SocialProvider.wechat)
                            : null,
                        icon: const Icon(Icons.chat_bubble),
                        label: Text(l10n.loginWithWechat),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: enableFakeSocialLogin
                            ? () => _login(context, SocialProvider.qq)
                            : null,
                        icon: const Icon(Icons.alternate_email),
                        label: Text(l10n.loginWithQq),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l10n.independentAccountNotice,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                      if (!enableFakeSocialLogin) ...[
                        const SizedBox(height: 12),
                        Text(
                          l10n.socialSdkUnavailable,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ],
                      if (controller.errorCode != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          l10n.loginFailed,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login(BuildContext context, SocialProvider provider) {
    final code = 'local-${provider.wireName}-default';
    return SessionScope.of(context).loginWithCode(provider, code);
  }
}
