import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appName.
  ///
  /// In zh, this message translates to:
  /// **'MomenPair'**
  String get appName;

  /// No description provided for @logsTitle.
  ///
  /// In zh, this message translates to:
  /// **'日志'**
  String get logsTitle;

  /// No description provided for @logsDescription.
  ///
  /// In zh, this message translates to:
  /// **'记录并分享家庭里的重要时刻。'**
  String get logsDescription;

  /// No description provided for @noticesTitle.
  ///
  /// In zh, this message translates to:
  /// **'注意'**
  String get noticesTitle;

  /// No description provided for @noticesDescription.
  ///
  /// In zh, this message translates to:
  /// **'集中查看家庭成员发布的提醒与注意事项。'**
  String get noticesDescription;

  /// No description provided for @countdownsTitle.
  ///
  /// In zh, this message translates to:
  /// **'倒数'**
  String get countdownsTitle;

  /// No description provided for @countdownsDescription.
  ///
  /// In zh, this message translates to:
  /// **'为重要日期创建倒计时或纪念日。'**
  String get countdownsDescription;

  /// No description provided for @notificationsTitle.
  ///
  /// In zh, this message translates to:
  /// **'通知'**
  String get notificationsTitle;

  /// No description provided for @notificationsDescription.
  ///
  /// In zh, this message translates to:
  /// **'家庭互动和账号安全消息会显示在这里。'**
  String get notificationsDescription;

  /// No description provided for @profileTitle.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get profileTitle;

  /// No description provided for @profileDescription.
  ///
  /// In zh, this message translates to:
  /// **'管理个人资料、当前登录平台和家庭成员。'**
  String get profileDescription;

  /// No description provided for @loginTitle.
  ///
  /// In zh, this message translates to:
  /// **'登录 MomenPair'**
  String get loginTitle;

  /// No description provided for @loginDescription.
  ///
  /// In zh, this message translates to:
  /// **'选择微信或 QQ 登录家庭空间。'**
  String get loginDescription;

  /// No description provided for @loginWithWechat.
  ///
  /// In zh, this message translates to:
  /// **'使用微信登录'**
  String get loginWithWechat;

  /// No description provided for @loginWithQq.
  ///
  /// In zh, this message translates to:
  /// **'使用 QQ 登录'**
  String get loginWithQq;

  /// No description provided for @independentAccountNotice.
  ///
  /// In zh, this message translates to:
  /// **'微信和 QQ 是两个独立账号，家庭与内容数据不会合并。'**
  String get independentAccountNotice;

  /// No description provided for @socialSdkUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'真实平台登录尚未配置，请在开发构建中测试。'**
  String get socialSdkUnavailable;

  /// No description provided for @loginFailed.
  ///
  /// In zh, this message translates to:
  /// **'登录失败，请检查后端服务后重试。'**
  String get loginFailed;

  /// No description provided for @wechatProvider.
  ///
  /// In zh, this message translates to:
  /// **'微信'**
  String get wechatProvider;

  /// No description provided for @qqProvider.
  ///
  /// In zh, this message translates to:
  /// **'QQ'**
  String get qqProvider;

  /// No description provided for @currentLoginProvider.
  ///
  /// In zh, this message translates to:
  /// **'当前登录平台'**
  String get currentLoginProvider;

  /// No description provided for @logout.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get logout;

  /// No description provided for @familySpace.
  ///
  /// In zh, this message translates to:
  /// **'家庭空间'**
  String get familySpace;

  /// No description provided for @noFamilyDescription.
  ///
  /// In zh, this message translates to:
  /// **'创建一个家庭空间，或使用家人分享的邀请码加入。一个账号同时只能属于一个家庭。'**
  String get noFamilyDescription;

  /// No description provided for @familyName.
  ///
  /// In zh, this message translates to:
  /// **'家庭名称'**
  String get familyName;

  /// No description provided for @createFamily.
  ///
  /// In zh, this message translates to:
  /// **'创建家庭'**
  String get createFamily;

  /// No description provided for @invitationCode.
  ///
  /// In zh, this message translates to:
  /// **'邀请码'**
  String get invitationCode;

  /// No description provided for @joinFamily.
  ///
  /// In zh, this message translates to:
  /// **'加入家庭'**
  String get joinFamily;

  /// No description provided for @familyAdmin.
  ///
  /// In zh, this message translates to:
  /// **'管理员'**
  String get familyAdmin;

  /// No description provided for @familyMember.
  ///
  /// In zh, this message translates to:
  /// **'成员'**
  String get familyMember;

  /// No description provided for @familyMemberCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 位成员'**
  String familyMemberCount(int count);

  /// No description provided for @createInvitation.
  ///
  /// In zh, this message translates to:
  /// **'创建一次性邀请码'**
  String get createInvitation;

  /// No description provided for @inviteCodeTitle.
  ///
  /// In zh, this message translates to:
  /// **'邀请码已创建'**
  String get inviteCodeTitle;

  /// No description provided for @inviteCodeDescription.
  ///
  /// In zh, this message translates to:
  /// **'请安全地发送给一位家人。邀请码 24 小时内有效且只能使用一次。'**
  String get inviteCodeDescription;

  /// No description provided for @copy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get copy;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @activeInvitations.
  ///
  /// In zh, this message translates to:
  /// **'邀请记录'**
  String get activeInvitations;

  /// No description provided for @invitationUsage.
  ///
  /// In zh, this message translates to:
  /// **'已使用 {used}/{max} 次'**
  String invitationUsage(int used, int max);

  /// No description provided for @invitationActive.
  ///
  /// In zh, this message translates to:
  /// **'可使用'**
  String get invitationActive;

  /// No description provided for @invitationExhausted.
  ///
  /// In zh, this message translates to:
  /// **'已用完'**
  String get invitationExhausted;

  /// No description provided for @invitationExpired.
  ///
  /// In zh, this message translates to:
  /// **'已过期'**
  String get invitationExpired;

  /// No description provided for @invitationRevoked.
  ///
  /// In zh, this message translates to:
  /// **'已撤销'**
  String get invitationRevoked;

  /// No description provided for @revoke.
  ///
  /// In zh, this message translates to:
  /// **'撤销'**
  String get revoke;

  /// No description provided for @familyMembers.
  ///
  /// In zh, this message translates to:
  /// **'家庭成员'**
  String get familyMembers;

  /// No description provided for @youLabel.
  ///
  /// In zh, this message translates to:
  /// **'你'**
  String get youLabel;

  /// No description provided for @makeAdmin.
  ///
  /// In zh, this message translates to:
  /// **'设为管理员'**
  String get makeAdmin;

  /// No description provided for @makeMember.
  ///
  /// In zh, this message translates to:
  /// **'设为普通成员'**
  String get makeMember;

  /// No description provided for @removeMember.
  ///
  /// In zh, this message translates to:
  /// **'移出家庭'**
  String get removeMember;

  /// No description provided for @leaveFamily.
  ///
  /// In zh, this message translates to:
  /// **'退出家庭'**
  String get leaveFamily;

  /// No description provided for @leaveFamilyConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认退出家庭？'**
  String get leaveFamilyConfirmTitle;

  /// No description provided for @leaveFamilyConfirmDescription.
  ///
  /// In zh, this message translates to:
  /// **'退出后将立即无法访问这个家庭的内容。最后一名管理员需先转让管理员角色。'**
  String get leaveFamilyConfirmDescription;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get confirm;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @familyOperationFailed.
  ///
  /// In zh, this message translates to:
  /// **'家庭操作失败，请检查权限、邀请码或网络后重试。'**
  String get familyOperationFailed;

  /// No description provided for @frameworkReady.
  ///
  /// In zh, this message translates to:
  /// **'功能框架已就绪'**
  String get frameworkReady;

  /// No description provided for @frameworkReadyDescription.
  ///
  /// In zh, this message translates to:
  /// **'后续领域功能将在此基础上逐步接入。'**
  String get frameworkReadyDescription;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
