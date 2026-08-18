// 领域功能尚未接入时的占位说明，对应客户端的 FeaturePlaceholder。

const locales = require('../../locales/index');

Component({
  data: {
    t: {},
  },

  attached() {
    this.setData({ t: locales.dict() });
  },
});
