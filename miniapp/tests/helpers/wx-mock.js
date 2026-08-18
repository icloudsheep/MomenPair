// 小程序 API 的最小替身。测试只依赖 Node 内置 test runner，不引入额外框架。

function installWxMock(options) {
  // envVersion 需要区分“未传入”和“显式为空”，因此不能用默认参数，
  // 否则无法覆盖读取不到发布通道的场景。
  const hasEnvVersion = Object.prototype.hasOwnProperty.call(options || {}, 'envVersion');
  const envVersion = hasEnvVersion ? options.envVersion : 'develop';
  const {
    language = 'zh_CN',
    enableReduceMotion = false,
    handleRequest = () => ({ statusCode: 200, data: {} }),
    loginResult = { code: 'wx-code-001' },
  } = options || {};

  const storage = new Map();
  const requests = [];

  const wx = {
    getAccountInfoSync() {
      return { miniProgram: { envVersion } };
    },
    getAppBaseInfo() {
      return { language };
    },
    getSystemInfoSync() {
      return { language, enableReduceMotion };
    },
    getStorageSync(key) {
      return storage.has(key) ? storage.get(key) : '';
    },
    setStorageSync(key, value) {
      storage.set(key, value);
    },
    removeStorageSync(key) {
      storage.delete(key);
    },
    login(config) {
      if (loginResult === null) {
        config.fail({ errMsg: 'login:fail auth deny' });
        return;
      }
      config.success(loginResult);
    },
    request(config) {
      requests.push(config);
      // 用 setImmediate 模拟异步返回，暴露并发刷新等时序问题。
      setImmediate(() => {
        const result = handleRequest(config, requests.length);
        if (result && result.fail === true) {
          config.fail({ errMsg: 'request:fail' });
          return;
        }
        config.success({ statusCode: result.statusCode, data: result.data });
      });
    },
    switchTab() {},
    reLaunch() {},
    showModal() {},
  };

  global.wx = wx;
  return { wx, storage, requests };
}

function uninstallWxMock() {
  delete global.wx;
}

// 构造后端登录成功响应，字段对齐 /api/v1/auth 契约。
function authPayload(overrides) {
  return Object.assign(
    {
      access_token: 'access-token-1',
      refresh_token: 'refresh-token-1',
      token_type: 'Bearer',
      expires_in: 900,
      user: {
        id: 'user-1',
        display_name: '微信本地用户',
        provider: 'wechat',
      },
    },
    overrides || {}
  );
}

function errorPayload(code) {
  return { detail: { code, message_key: `errors.${code}`, parameters: {} } };
}

module.exports = {
  installWxMock,
  uninstallWxMock,
  authPayload,
  errorPayload,
};
