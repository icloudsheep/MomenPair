const test = require('node:test');
const assert = require('node:assert/strict');

const { installWxMock, uninstallWxMock } = require('./helpers/wx-mock');
const env = require('../config/env');

test.afterEach(() => uninstallWxMock());

test('开发版通道使用本地接口并允许 Fake 登录回退', () => {
  installWxMock({ envVersion: 'develop' });
  const resolved = env.getEnv();
  assert.equal(resolved.name, 'development');
  assert.equal(resolved.apiBaseUrl, 'http://127.0.0.1:8000/api/v1/');
  assert.equal(resolved.allowFakeLoginFallback, true);
});

test('体验版与正式版禁止 Fake 登录回退', () => {
  installWxMock({ envVersion: 'trial' });
  assert.equal(env.getEnv().allowFakeLoginFallback, false);

  installWxMock({ envVersion: 'release' });
  const production = env.getEnv();
  assert.equal(production.name, 'production');
  assert.equal(production.allowFakeLoginFallback, false);
});

test('无法读取发布通道时按正式环境处理', () => {
  installWxMock({ envVersion: undefined });
  assert.equal(env.getEnv().name, 'production');
});

test('非开发环境必须使用 HTTPS', () => {
  assert.throws(
    () => env.assertTransportSecurity({ name: 'production', apiBaseUrl: 'http://a.example.com/' }),
    /必须使用 HTTPS/
  );
  assert.doesNotThrow(() =>
    env.assertTransportSecurity({ name: 'development', apiBaseUrl: 'http://127.0.0.1:8000/api/v1/' })
  );
});

test('resolveUrl 保留 API 版本前缀且不产生重复斜杠', () => {
  installWxMock({ envVersion: 'develop' });
  assert.equal(env.resolveUrl('auth/refresh'), 'http://127.0.0.1:8000/api/v1/auth/refresh');
  assert.equal(env.resolveUrl('/auth/refresh'), 'http://127.0.0.1:8000/api/v1/auth/refresh');
});

test('每个环境的接口地址都以斜杠结尾', () => {
  Object.values(env.ENVIRONMENTS).forEach((environment) => {
    assert.equal(env.normalizeBaseUrl(environment.apiBaseUrl).endsWith('/'), true);
  });
});
