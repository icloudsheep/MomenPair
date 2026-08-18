// 登录页。小程序只提供微信登录：QQ 互联没有小程序 SDK，
// 因此 QQ 账号只能在移动端或桌面客户端登录，这里只做只读说明。

const locales = require('../../locales/index');
const session = require('../../utils/session');

const HOME_PAGE = '/pages/logs/index';

Page({
  data: {
    t: {},
    status: session.STATUS.UNAUTHENTICATED,
    errorMessage: '',
  },

  onLoad() {
    this.setData({ t: locales.dict() });
    this._unsubscribe = session.subscribe((state) => this._applySession(state));
    this._applySession(session.getState());
  },

  onUnload() {
    if (typeof this._unsubscribe === 'function') {
      this._unsubscribe();
      this._unsubscribe = null;
    }
  },

  _applySession(state) {
    this.setData({
      status: state.status,
      errorMessage: state.errorCode === null ? '' : locales.errorMessage(state.errorCode),
    });
    if (state.status === session.STATUS.AUTHENTICATED) {
      this._enterHome();
    }
  },

  // 登录成功后切到一级页面；switchTab 目标必须是 tabBar 页面。
  _enterHome() {
    if (this._entering === true) {
      return;
    }
    this._entering = true;
    wx.switchTab({
      url: HOME_PAGE,
      fail: () => {
        this._entering = false;
      },
    });
  },

  onWechatLoginTap() {
    if (this.data.status === session.STATUS.LOADING) {
      return;
    }
    session.login();
  },
});
