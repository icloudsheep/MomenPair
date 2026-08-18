import 'package:flutter/material.dart';
import 'package:momen_pair_client/l10n/generated/app_localizations.dart';
import 'package:momen_pair_client/shared/presentation/feature_placeholder.dart';

class NoticesPage extends StatelessWidget {
  const NoticesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FeaturePlaceholder(
      title: l10n.noticesTitle,
      description: l10n.noticesDescription,
      icon: Icons.campaign,
    );
  }
}
