const test = require('node:test');
const assert = require('node:assert/strict');

const { installWxMock, uninstallWxMock } = require('./helpers/wx-mock');
const locales = require('../locales/index');
const zh = require('../locales/zh');
const en = require('../locales/en');

test.afterEach(() => {
  uninstallWxMock();
  locales.setLocale('zh');
});

test('中英文词典的键完全一致', () => {
  const zhKeys = Object.keys(zh).sort();
  const enKeys = Object.keys(en).sort();
  assert.deepEqual(zhKeys, enKeys);

  const zhErrorKeys = Object.keys(zh.errors).sort();
  const enErrorKeys = Object.keys(en.errors).sort();
  assert.deepEqual(zhErrorKeys, enErrorKeys);
});

test('词典不存在空文案', () => {
  [zh, en].forEach((dictionary) => {
    Object.entries(dictionary).forEach(([key, value]) => {
      if (typeof value === 'string') {
        assert.equal(value.length > 0, true, `${dictionary.locale}.${key} 不能为空`);
      }
    });
    Object.entries(dictionary.errors).forEach(([key, value]) => {
      assert.equal(value.length > 0, true, `${dictionary.locale}.errors.${key} 不能为空`);
    });
  });
});

test('语言标识归一化后回退到简体中文', () => {
  assert.equal(locales.normalizeLocale('zh_CN'), 'zh');
  assert.equal(locales.normalizeLocale('en-US'), 'en');
  assert.equal(locales.normalizeLocale('fr_FR'), 'zh');
  assert.equal(locales.normalizeLocale(''), 'zh');
  assert.equal(locales.normalizeLocale(undefined), 'zh');
});

test('按系统语言初始化当前词典', () => {
  installWxMock({ language: 'en_US' });
  assert.equal(locales.init(), 'en');
  assert.equal(locales.dict().logsTitle, 'Logs');

  installWxMock({ language: 'zh_CN' });
  assert.equal(locales.init(), 'zh');
  assert.equal(locales.dict().logsTitle, '日志');
});

test('未知错误码回退到统一提示', () => {
  locales.setLocale('zh');
  assert.equal(locales.errorMessage('social_code_invalid'), zh.errors.social_code_invalid);
  assert.equal(locales.errorMessage('some_unmapped_code'), zh.errors.request_failed);
});

test('五个一级页面标题均有文案', () => {
  ['logsTitle', 'noticesTitle', 'countdownsTitle', 'notificationsTitle', 'profileTitle'].forEach(
    (key) => {
      assert.equal(typeof zh[key], 'string');
      assert.equal(typeof en[key], 'string');
    }
  );
});
