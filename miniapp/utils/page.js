// 一级页面的共享装配：本地化词典、入场动画开关和登录态守卫。
// 领域功能后续在各页面的 extra 选项里追加，不需要重复这段样板。

const locales = require('../locales/index');
const motion = require('./motion');
const session = require('./session');

const LOGIN_PAGE = '/pages/login/index';

function createPage(options) {
  const { titleKey, descriptionKey, tabIndex, extra } = options;

  const base = {
    data: {
      t: locales.dict(),
      enterClass: 'mp-enter',
      status: session.getState().status,
      user: null,
    },

    onLoad() {
      this.setData({
        t: locales.dict(),
        enterClass: motion.enterClass(motion.prefersReducedMotion()),
        title: locales.dict()[titleKey],
        description: locales.dict()[descriptionKey],
      });
      this._unsubscribe = session.subscribe((state) => this._applySession(state));
      this._applySession(session.getState());
    },

    onShow() {
      // 自定义 tabBar 是页面级组件，切页后需要重新同步选中项。
      const tabBar = typeof this.getTabBar === 'function' ? this.getTabBar() : null;
      if (tabBar) {
        tabBar.setSelected(tabIndex);
      }
      this._applySession(session.getState());
    },

    onUnload() {
      if (typeof this._unsubscribe === 'function') {
        this._unsubscribe();
        this._unsubscribe = null;
      }
    },

    _applySession(state) {
      this.setData({ status: state.status, user: state.user });
      // 页面可实现 onSessionChange 派生自己的展示字段，避免在 WXML 里写表达式。
      if (typeof this.onSessionChange === 'function') {
        this.onSessionChange(state);
      }
      if (state.status === session.STATUS.UNAUTHENTICATED) {
        this._redirectToLogin();
      }
    },

    // 未登录时统一跳转登录页。用 reLaunch 关闭全部页面，避免 tabBar 页面栈
    // 保留已登录时的内容；跳转中重复触发会被 _redirecting 拦截。
    _redirectToLogin() {
      if (this._redirecting === true) {
        return;
      }
      this._redirecting = true;
      wx.reLaunch({
        url: LOGIN_PAGE,
        fail: () => {
          this._redirecting = false;
        },
      });
    },
  };

  // data 需要单独合并：直接 Object.assign 会让页面自带的 data 整体覆盖基础字段。
  const overrides = extra || {};
  const merged = Object.assign({}, base, overrides);
  merged.data = Object.assign({}, base.data, overrides.data || {});
  return merged;
}

module.exports = {
  LOGIN_PAGE,
  createPage,
};
