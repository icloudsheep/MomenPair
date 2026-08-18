// 环境配置按小程序发布通道推导，避免在业务代码里散落硬编码地址。
// develop = 开发版，trial = 体验版，release = 正式版。

const ENVIRONMENTS = {
  development: {
    name: 'development',
    apiBaseUrl: 'http://127.0.0.1:8000/api/v1/',
    // 后端 development/test 环境启用 Fake Provider 时，允许在 wx.login 不可用时回退到固定 code。
    allowFakeLoginFallback: true,
  },
  staging: {
    name: 'staging',
    apiBaseUrl: 'https://staging.example.com/api/v1/',
    allowFakeLoginFallback: false,
  },
  production: {
    name: 'production',
    apiBaseUrl: 'https://api.example.com/api/v1/',
    allowFakeLoginFallback: false,
  },
};

const CHANNEL_TO_ENVIRONMENT = {
  develop: 'development',
  trial: 'staging',
  release: 'production',
};

const REQUEST_TIMEOUT_MS = 15000;

// 无法读取发布通道时按最严格的环境处理，避免把开发配置带上线。
function resolveChannel() {
  if (typeof wx === 'undefined' || typeof wx.getAccountInfoSync !== 'function') {
    return 'release';
  }
  try {
    const accountInfo = wx.getAccountInfoSync();
    const channel = accountInfo && accountInfo.miniProgram && accountInfo.miniProgram.envVersion;
    return CHANNEL_TO_ENVIRONMENT[channel] ? channel : 'release';
  } catch (error) {
    return 'release';
  }
}

function normalizeBaseUrl(baseUrl) {
  return baseUrl.endsWith('/') ? baseUrl : `${baseUrl}/`;
}

function assertTransportSecurity(environment) {
  if (environment.name !== 'development' && environment.apiBaseUrl.startsWith('http://')) {
    throw new Error(`环境 ${environment.name} 必须使用 HTTPS 接口地址`);
  }
}

function getEnv() {
  const environment = ENVIRONMENTS[CHANNEL_TO_ENVIRONMENT[resolveChannel()]];
  assertTransportSecurity(environment);
  return {
    name: environment.name,
    apiBaseUrl: normalizeBaseUrl(environment.apiBaseUrl),
    allowFakeLoginFallback: environment.allowFakeLoginFallback,
    requestTimeout: REQUEST_TIMEOUT_MS,
  };
}

function resolveUrl(path) {
  const baseUrl = getEnv().apiBaseUrl;
  return `${baseUrl}${path.replace(/^\/+/, '')}`;
}

module.exports = {
  ENVIRONMENTS,
  CHANNEL_TO_ENVIRONMENT,
  getEnv,
  resolveUrl,
  normalizeBaseUrl,
  assertTransportSecurity,
};
