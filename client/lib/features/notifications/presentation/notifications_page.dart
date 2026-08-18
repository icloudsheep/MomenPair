import 'package:flutter/material.dart';
import 'package:momen_pair_client/l10n/generated/app_localizations.dart';
import 'package:momen_pair_client/shared/presentation/feature_placeholder.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FeaturePlaceholder(
      title: l10n.notificationsTitle,
      description: l10n.notificationsDescription,
      icon: Icons.notifications,
    );
  }
}
