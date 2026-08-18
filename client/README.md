# MomenPair Client

Flutter 客户端与 `server/` 完全分离，通过 `/api/v1` 接口访问后端。当前支持五个一级入口：日志、注意、倒数、通知和我的。

## 已有框架

- 手机端五项底部导航和桌面端自适应侧边导航；
- 现代玻璃化深色/浅色界面、小圆角内容面板；
- 玻璃导航效果及遵循系统“减少动态效果”的页面切换动画；
- 简体中文和英文 ARB 资源；
- 按 `features/` 划分的功能目录；
- API 环境配置、HTTP 客户端、认证状态机和平台安全存储；
- 开发环境微信/QQ 独立账号 Fake 登录；
- 家庭创建、邀请码加入、邀请撤销、成员角色和退出管理；
- 家庭日志游标列表、压缩图片上传、Markdown 编辑预览、详情、编辑与软删除；
- 日志点赞、评论、两层回复和版本冲突提示；
- 基础 Widget 测试。

## Flutter SDK 与平台环境

macOS 推荐直接下载 Flutter stable SDK 并加入 PATH：

```bash
mkdir -p ~/Support
cd ~/Support
git clone https://github.com/flutter/flutter.git --branch stable
echo 'export PATH="$HOME/Support/flutter/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
flutter doctor -v
```

仓库已经包含四端平台工程，不要再次运行 `flutter create .`。首次拉取后只需：

```bash
cd client
flutter pub get
flutter gen-l10n
```

平台要求：

- Android：Android Studio、Android SDK，目标最低版本后续按 `Baseline.md` 固定；
- iOS/macOS：macOS、Xcode 和 CocoaPods；
- Windows：Windows 10/11、Visual Studio 的 Desktop development with C++ 工作负载。

## 运行与检查

```bash
flutter devices
flutter run -d <device-id>
dart format lib test
flutter analyze
flutter test
```

## 源码结构

```text
lib/
├── app/                    应用入口、主题和后续路由
├── core/                   环境配置、网络和安全存储
├── features/
│   ├── auth/               独立社交账号与会话
│   ├── families/           家庭、邀请和成员关系
│   ├── home/               一级导航壳
│   ├── logs/               日志
│   ├── notices/            注意
│   ├── countdowns/         倒数
│   ├── notifications/      通知
│   └── profile/            我的
├── l10n/                   ARB 文案与生成文件目录
├── shared/                 跨功能 UI 组件
└── main.dart
```

每个功能后续按需要增加 `data/`、`domain/` 和 `presentation/`。只有真正被多个功能稳定复用的代码才能进入 `shared/`。

## 本地化

新增 UI 文案时同时修改：

- `lib/l10n/app_zh.arb`
- `lib/l10n/app_en.arb`

然后执行 `flutter gen-l10n`。业务代码不得硬编码面向用户的文本；服务端错误使用稳定错误码，由客户端映射为本地化文案。

## 后续接入顺序

1. 已完成：网络客户端、环境配置、安全存储和认证状态机；
2. 已完成：微信/QQ 独立账号的 Fake 登录、令牌轮换和退出闭环；
3. 已完成：家庭空间创建、邀请、加入、成员管理和即时权限边界；
4. 已完成：日志发布、图片压缩上传、Markdown 编辑预览、游标分页、详情、编辑删除、点赞、评论和回复；
5. 下一步：Mermaid/LaTeX 安全渲染与“注意”领域；
6. SSE、推送和小组件原生扩展。

## 本地认证联调

macOS、iOS 和 Windows 默认使用 `http://127.0.0.1:8000/api/v1/`。Android 模拟器使用：

```bash
flutter run -d android \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1/
```

Debug 构建默认启用 Fake 登录按钮，Release 默认禁用。可通过 `--dart-define=ENABLE_FAKE_SOCIAL_LOGIN=false` 在 Debug 中关闭。刷新令牌保存于平台安全存储，访问令牌只保留在应用内存中。

iOS/macOS 已在 Runner 工程配置 Keychain entitlement；macOS 另有应用沙箱网络客户端和用户所选文件只读权限，iOS 声明了照片库用途。更换 Bundle ID 或 Apple 开发团队后，应在 Xcode 重新选择 Team；真机部署仍需有效签名。
