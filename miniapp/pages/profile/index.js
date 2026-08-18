const { createPage } = require('../../utils/page');
const locales = require('../../locales/index');
const session = require('../../utils/session');

Page(
  createPage({
    titleKey: 'profileTitle',
    descriptionKey: 'profileDescription',
    tabIndex: 4,
    extra: {
      data: {
        avatarInitial: '',
      },

      // 头像占位取昵称首字符；昵称可能是 emoji 等代理对，用扩展运算符按字符切分。
      onSessionChange(state) {
        const displayName = state.user === null ? '' : state.user.displayName;
        this.setData({
          avatarInitial: displayName.length === 0 ? '' : [...displayName][0],
        });
      },

      // 登录平台是只读属性，页面不提供绑定、换绑、解绑或账号合并入口。
      onLogoutTap() {
        const dict = locales.dict();
        wx.showModal({
          title: dict.logoutConfirmTitle,
          content: dict.logoutConfirmContent,
          confirmText: dict.confirm,
          cancelText: dict.cancel,
          success: (result) => {
            if (result.confirm) {
              session.logout();
            }
          },
        });
      },
    },
  })
);
