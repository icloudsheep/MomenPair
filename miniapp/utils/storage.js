// 刷新令牌与设备标识的本地持久化。
//
// 平台限制：小程序没有 Keychain/Keystore 等系统安全存储，wx.setStorageSync
// 是按小程序 AppID 隔离的本地存储。因此本端刷新令牌的保护强度低于
// Android/iOS/macOS/Windows 客户端，需要依赖服务端短会话与令牌轮换兜底。

const REFRESH_TOKEN_KEY = 'momenpair.refresh_token';
const DEVICE_ID_KEY = 'momenpair.device_id';
const DEVICE_ID_PREFIX = 'miniprogram-';

function readSync(key) {
  try {
    const value = wx.getStorageSync(key);
    return typeof value === 'string' && value.length > 0 ? value : null;
  } catch (error) {
    return null;
  }
}

function writeSync(key, value) {
  try {
    wx.setStorageSync(key, value);
    return true;
  } catch (error) {
    return false;
  }
}

function removeSync(key) {
  try {
    wx.removeStorageSync(key);
  } catch (error) {
    // 清理失败不阻断退出流程，会话仍由服务端撤销。
  }
}

function readRefreshToken() {
  return readSync(REFRESH_TOKEN_KEY);
}

function writeRefreshToken(refreshToken) {
  return writeSync(REFRESH_TOKEN_KEY, refreshToken);
}

function clearRefreshToken() {
  removeSync(REFRESH_TOKEN_KEY);
}

// 服务端按设备记录会话，设备标识需要在同一小程序内保持稳定。
function getOrCreateDeviceId() {
  const existing = readSync(DEVICE_ID_KEY);
  if (existing !== null) {
    return existing;
  }
  const deviceId = `${DEVICE_ID_PREFIX}${randomId()}`;
  writeSync(DEVICE_ID_KEY, deviceId);
  return deviceId;
}

function randomId() {
  const timePart = Date.now().toString(36);
  const randomPart = Math.random().toString(36).slice(2, 10);
  return `${timePart}${randomPart}`;
}

module.exports = {
  REFRESH_TOKEN_KEY,
  DEVICE_ID_KEY,
  readRefreshToken,
  writeRefreshToken,
  clearRefreshToken,
  getOrCreateDeviceId,
};
