// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'MomenPair';

  @override
  String get logsTitle => '日志';

  @override
  String get logsDescription => '记录并分享家庭里的重要时刻。';

  @override
  String get noticesTitle => '注意';

  @override
  String get noticesDescription => '集中查看家庭成员发布的提醒与注意事项。';

  @override
  String get countdownsTitle => '倒数';

  @override
  String get countdownsDescription => '为重要日期创建倒计时或纪念日。';

  @override
  String get notificationsTitle => '通知';

  @override
  String get notificationsDescription => '家庭互动和账号安全消息会显示在这里。';

  @override
  String get profileTitle => '我的';

  @override
  String get profileDescription => '管理个人资料、当前登录平台和家庭成员。';

  @override
  String get loginTitle => '登录 MomenPair';

  @override
  String get loginDescription => '选择微信或 QQ 登录家庭空间。';

  @override
  String get loginWithWechat => '使用微信登录';

  @override
  String get loginWithQq => '使用 QQ 登录';

  @override
  String get independentAccountNotice => '微信和 QQ 是两个独立账号，家庭与内容数据不会合并。';

  @override
  String get socialSdkUnavailable => '真实平台登录尚未配置，请在开发构建中测试。';

  @override
  String get loginFailed => '登录失败，请检查后端服务后重试。';

  @override
  String get wechatProvider => '微信';

  @override
  String get qqProvider => 'QQ';

  @override
  String get currentLoginProvider => '当前登录平台';

  @override
  String get logout => '退出登录';

  @override
  String get frameworkReady => '功能框架已就绪';

  @override
  String get frameworkReadyDescription => '后续领域功能将在此基础上逐步接入。';
}
