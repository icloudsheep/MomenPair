# MomenPair 微信小程序端

`miniapp/` 是与 `client/`、`server/` 并列的独立端，拥有自己的配置、构建产物和测试。它不读取 Flutter 工程文件，也不依赖后端源码，只通过 `/api/v1` HTTPS JSON 接口协作。

## 与其他端的差异

小程序端不是 Flutter 客户端的移植，以下差异来自平台限制，不是设计选择：

| 能力 | 客户端（Android/iOS/macOS/Windows） | 小程序端 |
| --- | --- | --- |
| 登录平台 | 微信、QQ 两个独立账号 | 仅微信；QQ 互联无小程序 SDK |
| 刷新令牌存储 | Keychain / Keystore / Credential Locker | `wx.setStorageSync`，按 AppID 隔离 |
| 一级导航 | 底部导航栏与桌面侧边栏 | 自定义 tabBar，无桌面形态 |
| 小组件 | WidgetKit / App Widgets | 不支持 |

QQ 账号在小程序内不可登录，登录页对此只做只读说明，不提供任何绑定、换绑或账号找回入口。这与 `Baseline.md` 第 12～14 项一致：微信和 QQ 是完全隔离的独立账号。

## 目录结构

```text
miniapp/
├── app.js / app.json / app.wxss   小程序入口、全局配置与设计令牌
├── config/                        环境配置与接口路径
├── locales/                       中英文案，业务代码只引用键值
├── utils/                         请求、存储、会话、动画与页面装配
├── components/                    玻璃卡片与功能占位组件
├── custom-tab-bar/                自定义一级导航
├── pages/                         日志、注意、倒数、通知、我的、登录
└── tests/                         Node 内置 test runner 用例
```

## 本地运行

1. 按仓库根 `README.md` 启动后端，确认 `http://127.0.0.1:8000/api/v1/health/ready` 就绪。
2. 后端 `server/.env` 设置 `MOMENPAIR_SOCIAL_AUTH_MODE=fake`，使开发环境可用 Fake Provider 登录。该模式在 `production` 环境会拒绝启动。
3. 后端 `MOMENPAIR_CORS_ORIGINS` 需包含开发者工具来源，否则请求被 CORS 拦截。
4. 用微信开发者工具导入 `miniapp/` 目录。`project.config.json` 已填入 AppID，需确认它与目标小程序账号一致。
5. 开发阶段在开发者工具中勾选“不校验合法域名”，因为 `http://127.0.0.1` 不是备案域名。体验版和正式版必须使用已配置的 HTTPS 域名。

环境由发布通道自动推导，业务代码没有硬编码地址：

| 通道 | 环境 | 接口地址 |
| --- | --- | --- |
| 开发版 | development | `http://127.0.0.1:8000/api/v1/` |
| 体验版 | staging | `https://staging.example.com/api/v1/` |
| 正式版 | production | `https://api.example.com/api/v1/` |

`config/env.js` 中的 staging 与 production 地址是占位域名，需在确认正式域名后替换。非开发环境使用 `http://` 会在启动时抛错；读取不到发布通道时按正式环境处理，避免把开发配置带上线。

## 测试

```bash
cd miniapp
npm test
```

用例基于 Node 内置 test runner，不引入额外框架，用 `tests/helpers/wx-mock.js` 替身覆盖登录、令牌轮换、并发刷新、401 重放、退出和文案完整性。当前 41 个用例全部通过。这些用例不校验 WXML/WXSS 渲染，界面仍需在开发者工具和真机验证。

## 发布前必须完成

- [ ] 确认 `project.config.json` 的 AppID 与正式小程序账号一致。
- [ ] 确认 `config/env.js` 的 staging/production 域名，并在小程序后台登记 `request` 合法域名。
- [ ] `BLOCKER` 后端实现小程序专用登录端点。`wx.login` 返回的 code 需服务端调用 `jscode2session` 兑换，与开放平台移动应用的 code 不是同一种凭据；`config/api.js` 当前指向 `auth/wechat/mobile` 仅供 Fake Provider 联调。
- [ ] `BLOCKER` 完成小程序主体注册、类目选择与备案。封闭家庭空间涉及用户生成内容，需确认类目要求。
- [ ] 补充隐私政策与用户协议入口，并在小程序后台填写用户隐私保护指引。
- [ ] 确认微信小程序与开放平台移动应用能否取得同一 UnionID。取不到时，小程序登录会创建与手机客户端不同的独立账号，该行为必须在产品层确认后再上线。
- [ ] 在真机验证深色模式、安全区域、减少动态效果与中英文案。

## 已知限制

- 刷新令牌保存在小程序本地存储，防护强度低于系统安全存储，依赖服务端短会话与令牌轮换兜底。
- 领域功能（日志发布、评论点赞、倒计时、站内通知）尚未实现，五个页面目前只有导航、登录态与占位说明。
- Markdown、Mermaid、LaTeX 渲染未接入；小程序无法直接复用客户端的渲染库，需要单独选型。
- 实时事件（SSE）未接入，小程序对长连接的支持与客户端不同，需要单独设计。
