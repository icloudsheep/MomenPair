// wx.request 的 Promise 封装：统一 JSON、鉴权头和稳定错误码。
// 错误结构对齐 docs/api-conventions.md 的 detail.code，不向界面透出后端异常文本。

const { getEnv, resolveUrl } = require('../config/env');

class ApiError extends Error {
  constructor(code, statusCode) {
    super(`ApiError(${statusCode}, ${code})`);
    this.name = 'ApiError';
    this.code = code;
    this.statusCode = statusCode;
  }
}

// 网络层失败没有 HTTP 状态码，用 0 表示请求未到达服务端。
const NETWORK_ERROR_STATUS = 0;

function extractErrorCode(data) {
  if (data && typeof data === 'object' && data.detail && typeof data.detail === 'object') {
    const { code } = data.detail;
    if (typeof code === 'string' && code.length > 0) {
      return code;
    }
  }
  return 'request_failed';
}

function isSuccess(statusCode) {
  return statusCode >= 200 && statusCode < 300;
}

function request(path, options) {
  const { method = 'GET', data, accessToken } = options || {};
  const header = {
    accept: 'application/json',
    'content-type': 'application/json; charset=utf-8',
  };
  if (accessToken) {
    header.authorization = `Bearer ${accessToken}`;
  }

  return new Promise((resolve, reject) => {
    wx.request({
      url: resolveUrl(path),
      method,
      data,
      header,
      timeout: getEnv().requestTimeout,
      success(response) {
        if (!isSuccess(response.statusCode)) {
          reject(new ApiError(extractErrorCode(response.data), response.statusCode));
          return;
        }
        if (response.data === null || typeof response.data !== 'object') {
          reject(new ApiError('invalid_server_response', response.statusCode));
          return;
        }
        resolve(response.data);
      },
      fail() {
        // 不透出 wx 层的原始 errMsg，避免把内部地址与实现细节带到界面。
        reject(new ApiError('network_unavailable', NETWORK_ERROR_STATUS));
      },
    });
  });
}

function post(path, data, accessToken) {
  return request(path, { method: 'POST', data, accessToken });
}

function get(path, accessToken) {
  return request(path, { method: 'GET', accessToken });
}

module.exports = {
  ApiError,
  NETWORK_ERROR_STATUS,
  extractErrorCode,
  isSuccess,
  request,
  post,
  get,
};
