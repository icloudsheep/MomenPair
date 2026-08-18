const test = require('node:test');
const assert = require('node:assert/strict');

const { installWxMock, uninstallWxMock, errorPayload } = require('./helpers/wx-mock');
const { post, get, ApiError, extractErrorCode } = require('../utils/request');

test.afterEach(() => uninstallWxMock());

test('成功响应直接返回 JSON 对象', async () => {
  installWxMock({ handleRequest: () => ({ statusCode: 200, data: { ok: true } }) });
  assert.deepEqual(await get('auth/me', 'token'), { ok: true });
});

test('请求携带 JSON 头与 Bearer 令牌', async () => {
  const mock = installWxMock({ handleRequest: () => ({ statusCode: 200, data: {} }) });
  await post('auth/logout', { refresh_token: 'r1' }, 'access-1');

  const [config] = mock.requests;
  assert.equal(config.method, 'POST');
  assert.equal(config.url, 'http://127.0.0.1:8000/api/v1/auth/logout');
  assert.equal(config.header.authorization, 'Bearer access-1');
  assert.equal(config.header['content-type'], 'application/json; charset=utf-8');
  assert.deepEqual(config.data, { refresh_token: 'r1' });
});

test('未提供令牌时不发送 authorization 头', async () => {
  const mock = installWxMock({ handleRequest: () => ({ statusCode: 200, data: {} }) });
  await post('auth/wechat/mobile', { code: 'c' });
  assert.equal(mock.requests[0].header.authorization, undefined);
});

test('错误响应转换为后端稳定错误码', async () => {
  installWxMock({
    handleRequest: () => ({ statusCode: 401, data: errorPayload('social_code_invalid') }),
  });
  await assert.rejects(
    () => post('auth/wechat/mobile', { code: 'c' }),
    (error) => {
      assert.equal(error instanceof ApiError, true);
      assert.equal(error.code, 'social_code_invalid');
      assert.equal(error.statusCode, 401);
      return true;
    }
  );
});

test('缺少 detail.code 的错误响应回退到 request_failed', async () => {
  installWxMock({ handleRequest: () => ({ statusCode: 500, data: { message: 'boom' } }) });
  await assert.rejects(() => get('auth/me', 't'), /request_failed/);
});

test('网络失败使用 network_unavailable 且不透出原始 errMsg', async () => {
  installWxMock({ handleRequest: () => ({ fail: true }) });
  await assert.rejects(
    () => get('auth/me', 't'),
    (error) => {
      assert.equal(error.code, 'network_unavailable');
      assert.equal(error.statusCode, 0);
      assert.equal(/errMsg/.test(error.message), false);
      return true;
    }
  );
});

test('非对象响应体按无效响应处理', async () => {
  installWxMock({ handleRequest: () => ({ statusCode: 200, data: 'plain text' }) });
  await assert.rejects(() => get('auth/me', 't'), /invalid_server_response/);
});

test('extractErrorCode 容忍缺失或异常结构', () => {
  assert.equal(extractErrorCode(null), 'request_failed');
  assert.equal(extractErrorCode({ detail: 'text' }), 'request_failed');
  assert.equal(extractErrorCode({ detail: { code: '' } }), 'request_failed');
  assert.equal(extractErrorCode({ detail: { code: 'user_unavailable' } }), 'user_unavailable');
});
