// 玻璃质感卡片。只用于重点内容区域，保证正文与背景有足够对比度。

const motion = require('../../utils/motion');

Component({
  options: {
    // 允许宿主页面通过外部类调整间距，样式仍由组件自身收敛。
    addGlobalClass: true,
  },

  properties: {
    extClass: {
      type: String,
      value: '',
    },
  },

  data: {
    reduceMotion: false,
  },

  attached() {
    this.setData({ reduceMotion: motion.prefersReducedMotion() });
  },
});
