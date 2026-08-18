// 接口路径集中声明，与 docs/api-conventions.md 的 /api/v1 契约对应。
// 路径统一使用相对形式，由 config/env.js 的 resolveUrl 拼接版本前缀。

// 小程序 wx.login 返回的 code 需要服务端调用 jscode2session 兑换，
// 与开放平台移动应用的 code 不是同一种凭据。正式发布前后端必须提供
// 独立的小程序登录端点，当前指向 mobile 端点仅用于本地 Fake Provider 联调。
// 现状（2026-08-18）：后端尚未实现 auth/wechat/miniapp。
const WECHAT_LOGIN = 'auth/wechat/mobile';

const REFRESH = 'auth/refresh';
const ME = 'auth/me';
const LOGOUT = 'auth/logout';
const LOGOUT_ALL = 'auth/logout-all';

module.exports = {
  WECHAT_LOGIN,
  REFRESH,
  ME,
  LOGOUT,
  LOGOUT_ALL,
};
