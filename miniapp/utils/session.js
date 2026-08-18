// 会话状态与令牌生命周期。
//
// 访问令牌只保存在内存，刷新令牌落本地存储并在每次刷新时轮换，
// 与 docs/api-conventions.md 的令牌约定一致。

const api = require('../config/api');
const { post, request, uploadFile, downloadFile, ApiError } = require('./request');
const storage = require('./storage');
const { getEnv } = require('../config/env');

const STATUS = {
  LOADING: 'loading',
  AUTHENTICATED: 'authenticated',
  UNAUTHENTICATED: 'unauthenticated',
};

// 访问令牌提前 60 秒视为过期，避免请求在服务端校验时刚好越过有效期。
const EXPIRY_SKEW_MS = 60 * 1000;

const listeners = new Set();

let status = STATUS.LOADING;
let user = null;
let accessToken = null;
let accessTokenExpiresAt = 0;
let errorCode = null;
// 并发请求共用同一次刷新，避免刷新风暴与令牌家族被误判为重放。
let pendingRefresh = null;

function subscribe(listener) {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

function notify() {
  const snapshot = getState();
  listeners.forEach((listener) => listener(snapshot));
}

function getState() {
  return { status, user, errorCode };
}

function applySession(payload) {
  if (
    !payload ||
    typeof payload.access_token !== 'string' ||
    typeof payload.refresh_token !== 'string' ||
    typeof payload.expires_in !== 'number' ||
    !payload.user ||
    typeof payload.user.id !== 'string'
  ) {
    throw new ApiError('invalid_server_response', 200);
  }
  accessToken = payload.access_token;
  accessTokenExpiresAt = Date.now() + payload.expires_in * 1000;
  user = {
    id: payload.user.id,
    displayName: payload.user.display_name,
    provider: payload.user.provider,
  };
  storage.writeRefreshToken(payload.refresh_token);
  status = STATUS.AUTHENTICATED;
  errorCode = null;
  return user;
}

function clearSession(nextErrorCode) {
  accessToken = null;
  accessTokenExpiresAt = 0;
  user = null;
  status = STATUS.UNAUTHENTICATED;
  errorCode = nextErrorCode || null;
  storage.clearRefreshToken();
}

// 取得微信一次性 code。开发环境允许在 wx.login 不可用时回退到固定 code 联调 Fake Provider。
function fetchWechatCode() {
  return new Promise((resolve, reject) => {
    if (typeof wx === 'undefined' || typeof wx.login !== 'function') {
      if (getEnv().allowFakeLoginFallback) {
        resolve('local-wechat-default');
        return;
      }
      reject(new ApiError('social_auth_unavailable', 0));
      return;
    }
    wx.login({
      success(result) {
        if (typeof result.code === 'string' && result.code.length > 0) {
          resolve(result.code);
          return;
        }
        reject(new ApiError('wechat_login_denied', 0));
      },
      fail() {
        reject(new ApiError('wechat_login_denied', 0));
      },
    });
  });
}

async function login() {
  status = STATUS.LOADING;
  errorCode = null;
  notify();
  try {
    const code = await fetchWechatCode();
    const deviceId = storage.getOrCreateDeviceId();
    const payload = await post(api.WECHAT_LOGIN, { code, device_id: deviceId });
    applySession(payload);
  } catch (error) {
    clearSession(error instanceof ApiError ? error.code : 'request_failed');
  }
  notify();
  return getState();
}

// 冷启动恢复会话：本地无刷新令牌时直接进入未登录，不发起无意义请求。
async function restore() {
  const refreshToken = storage.readRefreshToken();
  if (refreshToken === null) {
    status = STATUS.UNAUTHENTICATED;
    notify();
    return getState();
  }
  status = STATUS.LOADING;
  notify();
  try {
    await refresh();
  } catch (error) {
    // 刷新失败已在 refresh 内按错误类型决定是否清理本地令牌。
  }
  notify();
  return getState();
}

function refresh() {
  if (pendingRefresh !== null) {
    return pendingRefresh;
  }
  const refreshToken = storage.readRefreshToken();
  if (refreshToken === null) {
    clearSession('refresh_token_invalid');
    return Promise.reject(new ApiError('refresh_token_invalid', 401));
  }
  pendingRefresh = post(api.REFRESH, { refresh_token: refreshToken })
    .then((payload) => applySession(payload))
    .catch((error) => {
      // 401 表示令牌确实失效，需要重新登录；其余错误保留令牌以便网络恢复后重试。
      if (error instanceof ApiError && error.statusCode === 401) {
        clearSession(error.code);
      } else {
        status = STATUS.UNAUTHENTICATED;
        errorCode = error instanceof ApiError ? error.code : 'request_failed';
      }
      throw error;
    })
    .finally(() => {
      pendingRefresh = null;
    });
  return pendingRefresh;
}

function hasUsableAccessToken() {
  return accessToken !== null && Date.now() + EXPIRY_SKEW_MS < accessTokenExpiresAt;
}

// 业务请求统一入口：先保证访问令牌可用，遇到 401 再刷新一次并重放。
async function authorized(path, options) {
  const { method = 'GET', data, headers } = options || {};
  if (!hasUsableAccessToken()) {
    await refresh();
    notify();
  }
  const send = () => request(path, { method, data, headers, accessToken });
  try {
    return await send();
  } catch (error) {
    if (error instanceof ApiError && error.statusCode === 401) {
      await refresh();
      notify();
      return send();
    }
    throw error;
  }
}

async function authorizedUpload(path, filePath, fieldName) {
  if (!hasUsableAccessToken()) {
    await refresh();
    notify();
  }
  const send = () => uploadFile(path, filePath, fieldName, accessToken);
  try {
    return await send();
  } catch (error) {
    if (error instanceof ApiError && error.statusCode === 401) {
      await refresh();
      notify();
      return send();
    }
    throw error;
  }
}

async function authorizedDownload(path) {
  if (!hasUsableAccessToken()) {
    await refresh();
    notify();
  }
  const send = () => downloadFile(path, accessToken);
  try {
    return await send();
  } catch (error) {
    if (error instanceof ApiError && error.statusCode === 401) {
      await refresh();
      notify();
      return send();
    }
    throw error;
  }
}

async function logout() {
  const refreshToken = storage.readRefreshToken();
  status = STATUS.LOADING;
  notify();
  try {
    if (refreshToken !== null) {
      await post(api.LOGOUT, { refresh_token: refreshToken });
    }
  } catch (error) {
    // 服务端撤销失败时仍清理本端会话，用户可见结果保持为已退出。
  } finally {
    clearSession(null);
    notify();
  }
  return getState();
}

// 仅供测试重置模块级状态。
function resetForTest() {
  status = STATUS.LOADING;
  user = null;
  accessToken = null;
  accessTokenExpiresAt = 0;
  errorCode = null;
  pendingRefresh = null;
  listeners.clear();
}

module.exports = {
  STATUS,
  EXPIRY_SKEW_MS,
  subscribe,
  getState,
  login,
  restore,
  refresh,
  authorized,
  authorizedUpload,
  authorizedDownload,
  logout,
  hasUsableAccessToken,
  resetForTest,
};
