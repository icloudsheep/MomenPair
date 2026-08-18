// 所有界面文案集中存放在 locales/ 下，业务代码只引用稳定键值。
// 首版实际交付简体中文，同时保留英文，与客户端 ARB 键名保持一致。

const zh = require('./zh');
const en = require('./en');

const DICTIONARIES = { zh, en };
const FALLBACK_LOCALE = 'zh';

let activeLocale = FALLBACK_LOCALE;

// 微信返回的语言标识形如 zh_CN、en、en_US，这里只取语言前缀。
function normalizeLocale(rawLocale) {
  if (typeof rawLocale !== 'string' || rawLocale.length === 0) {
    return FALLBACK_LOCALE;
  }
  const language = rawLocale.toLowerCase().replace('-', '_').split('_')[0];
  return DICTIONARIES[language] ? language : FALLBACK_LOCALE;
}

function detectLocale() {
  if (typeof wx === 'undefined') {
    return FALLBACK_LOCALE;
  }
  try {
    const appBaseInfo = typeof wx.getAppBaseInfo === 'function' ? wx.getAppBaseInfo() : null;
    if (appBaseInfo && appBaseInfo.language) {
      return normalizeLocale(appBaseInfo.language);
    }
    const systemInfo = typeof wx.getSystemInfoSync === 'function' ? wx.getSystemInfoSync() : null;
    return normalizeLocale(systemInfo && systemInfo.language);
  } catch (error) {
    return FALLBACK_LOCALE;
  }
}

function init() {
  activeLocale = detectLocale();
  return activeLocale;
}

function setLocale(rawLocale) {
  activeLocale = normalizeLocale(rawLocale);
  return activeLocale;
}

function getLocale() {
  return activeLocale;
}

// 页面直接把整份词典写入 data，WXML 里用 {{t.xxx}} 引用。
function dict() {
  return DICTIONARIES[activeLocale] || DICTIONARIES[FALLBACK_LOCALE];
}

// 未知错误码回退到统一文案，避免把后端异常文本直接展示给用户。
function errorMessage(code) {
  const messages = dict().errors;
  return messages[code] || messages.request_failed;
}

module.exports = {
  FALLBACK_LOCALE,
  normalizeLocale,
  detectLocale,
  init,
  setLocale,
  getLocale,
  dict,
  errorMessage,
};
