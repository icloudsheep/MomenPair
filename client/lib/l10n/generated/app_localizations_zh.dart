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
  String get familySpace => '家庭空间';

  @override
  String get noFamilyDescription => '创建一个家庭空间，或使用家人分享的邀请码加入。一个账号同时只能属于一个家庭。';

  @override
  String get familyName => '家庭名称';

  @override
  String get createFamily => '创建家庭';

  @override
  String get invitationCode => '邀请码';

  @override
  String get joinFamily => '加入家庭';

  @override
  String get familyAdmin => '管理员';

  @override
  String get familyMember => '成员';

  @override
  String familyMemberCount(int count) {
    return '$count 位成员';
  }

  @override
  String get createInvitation => '创建一次性邀请码';

  @override
  String get inviteCodeTitle => '邀请码已创建';

  @override
  String get inviteCodeDescription => '请安全地发送给一位家人。邀请码 24 小时内有效且只能使用一次。';

  @override
  String get copy => '复制';

  @override
  String get close => '关闭';

  @override
  String get activeInvitations => '邀请记录';

  @override
  String invitationUsage(int used, int max) {
    return '已使用 $used/$max 次';
  }

  @override
  String get invitationActive => '可使用';

  @override
  String get invitationExhausted => '已用完';

  @override
  String get invitationExpired => '已过期';

  @override
  String get invitationRevoked => '已撤销';

  @override
  String get revoke => '撤销';

  @override
  String get familyMembers => '家庭成员';

  @override
  String get youLabel => '你';

  @override
  String get makeAdmin => '设为管理员';

  @override
  String get makeMember => '设为普通成员';

  @override
  String get removeMember => '移出家庭';

  @override
  String get leaveFamily => '退出家庭';

  @override
  String get leaveFamilyConfirmTitle => '确认退出家庭？';

  @override
  String get leaveFamilyConfirmDescription =>
      '退出后将立即无法访问这个家庭的内容。最后一名管理员需先转让管理员角色。';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确认';

  @override
  String get retry => '重试';

  @override
  String get familyOperationFailed => '家庭操作失败，请检查权限、邀请码或网络后重试。';

  @override
  String get frameworkReady => '功能框架已就绪';

  @override
  String get frameworkReadyDescription => '后续领域功能将在此基础上逐步接入。';
}
