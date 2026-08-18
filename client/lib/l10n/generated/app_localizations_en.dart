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
  String get familySpace => 'Family space';

  @override
  String get noFamilyDescription =>
      'Create a family space or join with an invitation code. An account can belong to only one family at a time.';

  @override
  String get familyName => 'Family name';

  @override
  String get createFamily => 'Create family';

  @override
  String get invitationCode => 'Invitation code';

  @override
  String get joinFamily => 'Join family';

  @override
  String get familyAdmin => 'Admin';

  @override
  String get familyMember => 'Member';

  @override
  String familyMemberCount(int count) {
    return '$count members';
  }

  @override
  String get createInvitation => 'Create one-time invitation';

  @override
  String get inviteCodeTitle => 'Invitation created';

  @override
  String get inviteCodeDescription =>
      'Share this securely with one family member. It expires in 24 hours and can be used once.';

  @override
  String get copy => 'Copy';

  @override
  String get close => 'Close';

  @override
  String get activeInvitations => 'Invitations';

  @override
  String invitationUsage(int used, int max) {
    return 'Used $used/$max times';
  }

  @override
  String get invitationActive => 'Available';

  @override
  String get invitationExhausted => 'Used';

  @override
  String get invitationExpired => 'Expired';

  @override
  String get invitationRevoked => 'Revoked';

  @override
  String get revoke => 'Revoke';

  @override
  String get familyMembers => 'Family members';

  @override
  String get youLabel => 'you';

  @override
  String get makeAdmin => 'Make admin';

  @override
  String get makeMember => 'Make member';

  @override
  String get removeMember => 'Remove from family';

  @override
  String get leaveFamily => 'Leave family';

  @override
  String get leaveFamilyConfirmTitle => 'Leave this family?';

  @override
  String get leaveFamilyConfirmDescription =>
      'You will immediately lose access to this family\'s content. The last admin must transfer the admin role first.';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get retry => 'Retry';

  @override
  String get familyOperationFailed =>
      'The family operation failed. Check your permission, invitation, or network and try again.';

  @override
  String get logsRequireFamily =>
      'Create or join a family from Profile first. Logs are visible only to current family members.';

  @override
  String get logsEmptyTitle => 'No family logs yet';

  @override
  String get logsEmptyDescription =>
      'Write the first log and capture a moment worth remembering together.';

  @override
  String get createLog => 'Write log';

  @override
  String get editLog => 'Edit log';

  @override
  String get logDetailTitle => 'Log details';

  @override
  String get logTitleLabel => 'Title';

  @override
  String get logSubtitleLabel => 'Subtitle (optional)';

  @override
  String get logBodyLabel => 'Body';

  @override
  String get logBodyHint => 'Write about this moment…';

  @override
  String get logTitleRequired => 'Enter a log title';

  @override
  String get logBodyRequired => 'Enter log content';

  @override
  String get editMode => 'Edit';

  @override
  String get previewMode => 'Preview';

  @override
  String get addPhotos => 'Add photos';

  @override
  String get photoLimitHint => 'Up to 9 photos, compressed before publishing';

  @override
  String get imageUploadFailed => 'Photo upload failed. Try again later.';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String get previewEmpty => 'Your preview will appear here';

  @override
  String get publish => 'Publish';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get deleteLogTitle => 'Delete this log?';

  @override
  String get deleteLogDescription =>
      'Family members will no longer be able to access its content. This cannot be undone in the app.';

  @override
  String get loadMore => 'Load more';

  @override
  String likesCount(int count) {
    return '$count likes';
  }

  @override
  String commentsCount(int count) {
    return '$count comments';
  }

  @override
  String get commentsTitle => 'Comments';

  @override
  String get commentsEmpty => 'No comments yet. Start the conversation.';

  @override
  String get addComment => 'Add comment';

  @override
  String get commentHint => 'Write a comment…';

  @override
  String get send => 'Send';

  @override
  String get reply => 'Reply';

  @override
  String replyTo(String name) {
    return 'Reply to @$name';
  }

  @override
  String get deletedComment => 'This comment was deleted';

  @override
  String get logVersionConflict =>
      'This content changed on another device. Return to the list, refresh, and edit again.';

  @override
  String get logOperationFailed =>
      'The log operation failed. Check your family access or network and try again.';

  @override
  String get frameworkReady => 'Feature foundation is ready';

  @override
  String get frameworkReadyDescription =>
      'Domain features will be connected here incrementally.';
}
