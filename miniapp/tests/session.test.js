const test = require('node:test');
const assert = require('node:assert/strict');

const { installWxMock, uninstallWxMock, authPayload, errorPayload } = require('./helpers/wx-mock');
const session = require('../utils/session');
const storage = require('../utils/storage');

test.afterEach(() => {
  session.resetForTest();
  uninstallWxMock();
});

test('微信登录成功后保存会话并轮换刷新令牌', async () => {
  installWxMock({
    loginResult: { code: 'wx-code-abc' },
    handleRequest: () => ({ statusCode: 200, data: authPayload() }),
  });

  const state = await session.login();
  assert.equal(state.status, session.STATUS.AUTHENTICATED);
  assert.equal(state.user.provider, 'wechat');
  assert.equal(state.errorCode, null);
  assert.equal(storage.readRefreshToken(), 'refresh-token-1');
});

test('登录请求提交 wx.login 的 code 与稳定设备标识', async () => {
  const mock = installWxMock({
    loginResult: { code: 'wx-code-abc' },
    handleRequest: () => ({ statusCode: 200, data: authPayload() }),
  });

  await session.login();
  const [config] = mock.requests;
  assert.equal(config.url.endsWith('/auth/wechat/mobile'), true);
  assert.equal(config.data.code, 'wx-code-abc');
  assert.equal(config.data.device_id.startsWith('miniprogram-'), true);
});

test('用户拒绝微信授权时给出可恢复错误且不建立会话', async () => {
  installWxMock({ loginResult: null });
  const state = await session.login();
  assert.equal(state.status, session.STATUS.UNAUTHENTICATED);
  assert.equal(state.errorCode, 'wechat_login_denied');
  assert.equal(storage.readRefreshToken(), null);
});

test('后端拒绝 code 时保留稳定错误码', async () => {
  installWxMock({
    handleRequest: () => ({ statusCode: 401, data: errorPayload('social_code_invalid') }),
  });
  const state = await session.login();
  assert.equal(state.status, session.STATUS.UNAUTHENTICATED);
  assert.equal(state.errorCode, 'social_code_invalid');
});

test('缺少必填字段的登录响应按无效响应处理', async () => {
  installWxMock({
    handleRequest: () => ({ statusCode: 200, data: { access_token: 'only-access' } }),
  });
  const state = await session.login();
  assert.equal(state.status, session.STATUS.UNAUTHENTICATED);
  assert.equal(state.errorCode, 'invalid_server_response');
});

test('本地无刷新令牌时冷启动直接进入未登录', async () => {
  const mock = installWxMock({});
  const state = await session.restore();
  assert.equal(state.status, session.STATUS.UNAUTHENTICATED);
  assert.equal(mock.requests.length, 0);
});

test('冷启动用刷新令牌恢复会话', async () => {
  installWxMock({
    handleRequest: () => ({
      statusCode: 200,
      data: authPayload({ refresh_token: 'refresh-token-2' }),
    }),
  });
  storage.writeRefreshToken('refresh-token-1');

  const state = await session.restore();
  assert.equal(state.status, session.STATUS.AUTHENTICATED);
  assert.equal(storage.readRefreshToken(), 'refresh-token-2');
});

test('刷新令牌失效时清理本地令牌', async () => {
  installWxMock({
    handleRequest: () => ({ statusCode: 401, data: errorPayload('refresh_token_invalid') }),
  });
  storage.writeRefreshToken('stale-token');

  const state = await session.restore();
  assert.equal(state.status, session.STATUS.UNAUTHENTICATED);
  assert.equal(state.errorCode, 'refresh_token_invalid');
  assert.equal(storage.readRefreshToken(), null);
});

test('网络失败不清理刷新令牌，便于恢复后重试', async () => {
  installWxMock({ handleRequest: () => ({ fail: true }) });
  storage.writeRefreshToken('refresh-token-1');

  const state = await session.restore();
  assert.equal(state.status, session.STATUS.UNAUTHENTICATED);
  assert.equal(state.errorCode, 'network_unavailable');
  assert.equal(storage.readRefreshToken(), 'refresh-token-1');
});

test('并发刷新只发起一次请求，避免刷新风暴与误判重放', async () => {
  const mock = installWxMock({
    handleRequest: () => ({
      statusCode: 200,
      data: authPayload({ refresh_token: 'refresh-token-2' }),
    }),
  });
  storage.writeRefreshToken('refresh-token-1');

  await Promise.all([session.refresh(), session.refresh(), session.refresh()]);
  const refreshCalls = mock.requests.filter((config) => config.url.endsWith('/auth/refresh'));
  assert.equal(refreshCalls.length, 1);
});

test('访问令牌过期时业务请求先刷新再发起', async () => {
  const mock = installWxMock({
    handleRequest: (config) => {
      if (config.url.endsWith('/auth/refresh')) {
        // expires_in 为 0，配合提前量后立即视为过期。
        return { statusCode: 200, data: authPayload({ expires_in: 0 }) };
      }
      return { statusCode: 200, data: { items: [], next_cursor: null } };
    },
  });
  storage.writeRefreshToken('refresh-token-1');

  await session.authorized('logs');
  const urls = mock.requests.map((config) => config.url);
  assert.equal(urls[0].endsWith('/auth/refresh'), true);
  assert.equal(urls[1].endsWith('/logs'), true);
});

test('业务请求遇到 401 时刷新一次并重放', async () => {
  let businessCalls = 0;
  const mock = installWxMock({
    handleRequest: (config) => {
      if (config.url.endsWith('/auth/refresh')) {
        return { statusCode: 200, data: authPayload() };
      }
      businessCalls += 1;
      if (businessCalls === 1) {
        return { statusCode: 401, data: errorPayload('access_token_invalid') };
      }
      return { statusCode: 200, data: { items: [] } };
    },
  });
  storage.writeRefreshToken('refresh-token-1');
  await session.refresh();

  const result = await session.authorized('logs');
  assert.deepEqual(result, { items: [] });
  assert.equal(businessCalls, 2);
  const refreshCalls = mock.requests.filter((config) => config.url.endsWith('/auth/refresh'));
  assert.equal(refreshCalls.length, 2);
});

test('刷新后仍返回 401 时不再无限重试', async () => {
  installWxMock({
    handleRequest: (config) => {
      if (config.url.endsWith('/auth/refresh')) {
        return { statusCode: 200, data: authPayload() };
      }
      return { statusCode: 401, data: errorPayload('access_token_invalid') };
    },
  });
  storage.writeRefreshToken('refresh-token-1');
  await session.refresh();

  await assert.rejects(() => session.authorized('logs'), /access_token_invalid/);
});

test('退出登录清理本地令牌并撤销服务端会话', async () => {
  const mock = installWxMock({
    handleRequest: () => ({ statusCode: 200, data: authPayload() }),
  });
  await session.login();

  const state = await session.logout();
  assert.equal(state.status, session.STATUS.UNAUTHENTICATED);
  assert.equal(state.user, null);
  assert.equal(storage.readRefreshToken(), null);
  const logoutCalls = mock.requests.filter((config) => config.url.endsWith('/auth/logout'));
  assert.equal(logoutCalls.length, 1);
});

test('服务端撤销失败时本端仍完成退出', async () => {
  installWxMock({
    handleRequest: (config) => {
      if (config.url.endsWith('/auth/logout')) {
        return { fail: true };
      }
      return { statusCode: 200, data: authPayload() };
    },
  });
  await session.login();

  const state = await session.logout();
  assert.equal(state.status, session.STATUS.UNAUTHENTICATED);
  assert.equal(storage.readRefreshToken(), null);
});

test('订阅者收到状态变更并可取消订阅', async () => {
  installWxMock({ handleRequest: () => ({ statusCode: 200, data: authPayload() }) });
  const observed = [];
  const unsubscribe = session.subscribe((state) => observed.push(state.status));

  await session.login();
  assert.equal(observed.includes(session.STATUS.LOADING), true);
  assert.equal(observed[observed.length - 1], session.STATUS.AUTHENTICATED);

  unsubscribe();
  const countBefore = observed.length;
  await session.logout();
  assert.equal(observed.length, countBefore);
});

test('会话状态不对外暴露访问令牌与刷新令牌', async () => {
  installWxMock({ handleRequest: () => ({ statusCode: 200, data: authPayload() }) });
  await session.login();

  const state = session.getState();
  const serialized = JSON.stringify(state);
  assert.equal(serialized.includes('access-token-1'), false);
  assert.equal(serialized.includes('refresh-token-1'), false);
  assert.equal(Object.keys(state).sort().join(','), 'errorCode,status,user');
});
