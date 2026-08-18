// 读取系统“减少动态效果”开关，供页面决定是否播放入场动画。
// 基础库或系统未提供该字段时按开启动画处理，与客户端默认行为一致。

function prefersReducedMotion() {
  if (typeof wx === 'undefined' || typeof wx.getSystemInfoSync !== 'function') {
    return false;
  }
  try {
    const systemInfo = wx.getSystemInfoSync();
    return systemInfo && systemInfo.enableReduceMotion === true;
  } catch (error) {
    return false;
  }
}

// 返回入场动画类名，减少动态效果时附加静态类关闭动画。
function enterClass(reduceMotion) {
  return reduceMotion ? 'mp-enter mp-enter--static' : 'mp-enter';
}

module.exports = {
  prefersReducedMotion,
  enterClass,
};
