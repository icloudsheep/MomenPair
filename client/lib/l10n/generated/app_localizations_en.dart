// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'MomenPair';

  @override
  String get logsTitle => 'Logs';

  @override
  String get logsDescription => 'Capture and share important family moments.';

  @override
  String get noticesTitle => 'Notices';

  @override
  String get noticesDescription =>
      'Keep family reminders and cautions in one place.';

  @override
  String get countdownsTitle => 'Countdowns';

  @override
  String get countdownsDescription =>
      'Create countdowns and anniversaries for key dates.';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsDescription =>
      'Family activity and account security messages appear here.';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileDescription =>
      'Manage your profile, current sign-in provider, and family members.';

  @override
  String get loginTitle => 'Sign in to MomenPair';

  @override
  String get loginDescription =>
      'Choose WeChat or QQ to enter your family space.';

  @override
  String get loginWithWechat => 'Continue with WeChat';

  @override
  String get loginWithQq => 'Continue with QQ';

  @override
  String get independentAccountNotice =>
      'WeChat and QQ are separate accounts. Family and content data are never merged.';

  @override
  String get socialSdkUnavailable =>
      'Live provider sign-in is not configured. Use a development build for testing.';

  @override
  String get loginFailed =>
      'Sign-in failed. Check the backend service and try again.';

  @override
  String get wechatProvider => 'WeChat';

  @override
  String get qqProvider => 'QQ';

  @override
  String get currentLoginProvider => 'Current sign-in provider';

  @override
  String get logout => 'Sign out';

  @override
  String get frameworkReady => 'Feature foundation is ready';

  @override
  String get frameworkReadyDescription =>
      'Domain features will be connected here incrementally.';
}
