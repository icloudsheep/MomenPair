const test = require('node:test');
const assert = require('node:assert/strict');

const { installWxMock, uninstallWxMock } = require('./helpers/wx-mock');
const storage = require('../utils/storage');

test.afterEach(() => uninstallWxMock());

test('刷新令牌可写入、读取与清理', () => {
  installWxMock({});
  assert.equal(storage.readRefreshToken(), null);

  storage.writeRefreshToken('refresh-1');
  assert.equal(storage.readRefreshToken(), 'refresh-1');

  storage.clearRefreshToken();
  assert.equal(storage.readRefreshToken(), null);
});

test('设备标识生成后保持稳定', () => {
  installWxMock({});
  const first = storage.getOrCreateDeviceId();
  const second = storage.getOrCreateDeviceId();
  assert.equal(first, second);
  assert.equal(first.startsWith('miniprogram-'), true);
});

test('存储异常时读取返回 null 而不抛出', () => {
  installWxMock({});
  global.wx.getStorageSync = () => {
    throw new Error('storage unavailable');
  };
  assert.equal(storage.readRefreshToken(), null);
});

test('写入失败返回 false 而不抛出', () => {
  installWxMock({});
  global.wx.setStorageSync = () => {
    throw new Error('quota exceeded');
  };
  assert.equal(storage.writeRefreshToken('refresh-1'), false);
});
