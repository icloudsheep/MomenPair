// 自定义 tabBar：承载玻璃质感与非线性选中动画，文案来自 locales。
// 微信要求自定义 tabBar 固定放在 custom-tab-bar/ 目录。

const locales = require('../locales/index');
const motion = require('../utils/motion');

const TAB_PAGES = [
  { pagePath: '/pages/logs/index', labelKey: 'logsTitle', icon: '✦' },
  { pagePath: '/pages/notices/index', labelKey: 'noticesTitle', icon: '❋' },
  { pagePath: '/pages/countdowns/index', labelKey: 'countdownsTitle', icon: '◷' },
  { pagePath: '/pages/notifications/index', labelKey: 'notificationsTitle', icon: '◈' },
  { pagePath: '/pages/profile/index', labelKey: 'profileTitle', icon: '◉' },
];

Component({
  data: {
    selected: 0,
    reduceMotion: false,
    tabs: [],
  },

  attached() {
    const dict = locales.dict();
    this.setData({
      reduceMotion: motion.prefersReducedMotion(),
      tabs: TAB_PAGES.map((tab) => ({
        pagePath: tab.pagePath,
        icon: tab.icon,
        label: dict[tab.labelKey],
      })),
    });
  },

  methods: {
    setSelected(index) {
      if (typeof index === 'number' && index !== this.data.selected) {
        this.setData({ selected: index });
      }
    },

    onTap(event) {
      const { index, path } = event.currentTarget.dataset;
      if (index === this.data.selected) {
        return;
      }
      // 先切页再更新选中态，避免切换失败时高亮与实际页面不一致。
      wx.switchTab({
        url: path,
        success: () => this.setData({ selected: index }),
      });
    },
  },
});
