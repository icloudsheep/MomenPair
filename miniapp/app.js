const locales = require('./locales/index');
const session = require('./utils/session');
const { getEnv } = require('./config/env');

App({
  globalData: {
    locale: locales.FALLBACK_LOCALE,
    environment: 'production',
  },

  onLaunch() {
    this.globalData.locale = locales.init();
    this.globalData.environment = getEnv().name;
    // 冷启动即尝试恢复会话，页面通过 session.subscribe 获得结果。
    session.restore();
  },
});
