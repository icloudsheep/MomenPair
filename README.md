# MomenPair

MomenPair 是一个面向受邀家庭成员的封闭家庭空间。仓库采用客户端与后端分离的 monorepo：Flutter 客户端覆盖 Android、iOS、macOS 和 Windows，FastAPI 后端提供身份、家庭、内容、倒计时、通知和媒体能力。

账号仅支持微信和 QQ 登录，两种平台分别创建独立账号。一个用户只能有一个登录身份，不支持手机号、短信验证码、跨平台绑定、换绑或账号合并。

当前已完成认证、家庭空间和家庭日志三个切片：Flutter 客户端提供微信/QQ 独立账号登录、家庭管理，以及带压缩图片的日志发布、Markdown 编辑预览、列表、详情、编辑、删除、点赞、评论和回复；小程序同步支持日志列表、发布和点赞；后端提供令牌轮换、一次性邀请、即时成员权限校验、私有图片存储和日志互动 API。真实微信/QQ SDK、Mermaid/LaTeX 图形渲染、注意、倒计时和推送仍待实现。

## 目录结构

```text
MomenPair/
├── client/                 Flutter 客户端，独立依赖与测试
├── miniapp/                微信小程序端，独立配置与测试
├── server/                 FastAPI 后端，独立依赖、迁移与测试
├── docs/                   架构和接口约定
├── Baseline.md             产品需求评估与决策基线
├── compose.yaml            本地后端与基础设施编排
└── README.md               项目总览与统一开发入口
```

客户端不得直接依赖后端源码，后端也不得读取客户端工程文件；各端只通过版本化 HTTPS API、实时事件协议和生成后的接口契约协作。小程序端与 Flutter 客户端同样相互独立，不共享源码。

小程序端只能使用微信登录，因为 QQ 互联不提供小程序 SDK；QQ 账号仍需在手机或桌面客户端登录。详见[小程序端说明](./miniapp/README.md)。

## 技术基线

| 范围 | 技术 |
| --- | --- |
| 客户端 | Flutter、Dart、玻璃化自适应界面、ARB 本地化 |
| 小程序端 | 微信小程序原生框架、自定义 tabBar、键值化文案 |
| 后端 | Python 3.12+、FastAPI、Pydantic v2、SQLAlchemy 2 |
| 数据 | MySQL 8.4 LTS、Redis 7.4、MinIO/S3 兼容对象存储 |
| 迁移 | Alembic |
| 实时与异步 | SSE/Outbox/Worker，后续迭代接入 |
| API | HTTPS JSON、`/api/v1` 版本前缀、OpenAPI |

## 快速开始

### 1. 获取配置

```bash
cp .env.example .env
cp server/.env.example server/.env
```

开发前必须替换两个文件中的示例密码和密钥。根目录 `.env` 供 Compose 使用，`server/.env` 供本地启动的 Python 服务使用，两者作用域不同。

### 2. 启动后端

使用 Docker Compose 启动 API、MySQL、Redis 和 MinIO：

```bash
docker compose up --build
```

启动后可访问：

- API 文档：<http://127.0.0.1:8000/docs>
- 存活检查：<http://127.0.0.1:8000/api/v1/health/live>
- 就绪检查：<http://127.0.0.1:8000/api/v1/health/ready>
- MinIO 控制台：<http://127.0.0.1:9001>

也可以只用 Compose 启动依赖，再在宿主机运行 API：

```bash
docker compose up mysql redis minio
cd server
uv sync --group dev
uv run alembic upgrade head
uv run uvicorn momen_pair.main:app --reload
```

新增或修改模型后创建迁移：

```bash
cd server
uv run alembic revision --autogenerate -m "create account and family tables"
uv run alembic upgrade head
```

迁移故障排查：

- 容器提示 `No 'script_location' key found` 时，说明正在运行的 API 镜像过旧；执行 `docker compose up --build -d api` 后重试迁移。
- MySQL 提示 `Access denied` 且此前修改过 `.env` 密码时，通常是已有数据卷仍保留首次初始化的凭据。需要保留数据时不要删除卷，应使用原凭据登录后修改数据库用户；确认本地数据库可丢弃时，先执行 `docker compose down`，再仅删除 `momen-pair_mysql-data` 卷并重新启动。删除该卷会永久清除本地 MySQL 数据。

### 3. 启动客户端

需要稳定版 Flutter SDK，以及目标平台对应的官方构建工具。仓库已包含 Android、iOS、macOS 和 Windows 平台工程，无需再次执行 `flutter create`：

```bash
cd client
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
flutter run -d macos
```

业务源码位于 `client/lib/`。平台目录只承载构建配置、权限和必要的第三方 SDK 适配，不承载可共享业务规则。Flutter SDK 与 Docker Desktop 安装和故障排查见[客户端说明](./client/README.md)与本页后端启动章节。

## 日常开发命令

后端：

```bash
cd server
uv run ruff format --check .
uv run ruff check .
uv run mypy src
uv run pytest
```

客户端：

```bash
cd client
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

macOS、iOS 和 Windows 本地调试默认连接 `http://127.0.0.1:8000/api/v1/`。Android 模拟器需显式指定宿主机地址：

```bash
flutter run -d android \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1/
```

Debug 构建默认显示本地微信/QQ Fake 登录；Release 构建默认关闭。Fake Provider 只允许后端 `development` 或 `test` 环境，生产配置会拒绝启动。

iOS/macOS 已配置 Keychain entitlement；macOS Debug 构建同时启用应用沙箱网络客户端权限。更换 Apple 开发者账号或 Bundle ID 后，需要在 Xcode 中重新选择自己的 Team 并生成匹配的开发描述文件。

## 环境与数据约束

- 数据库保存 UTC 时间；客户端按事件时区或用户时区展示。
- 每条家庭数据必须带 `family_id`，服务端按已生效的家庭成员关系校验访问权。
- 首版内容只支持“家庭内公开”，数据模型预留“仅自己”，客户端不得自行启用该状态。
- 图片按私有对象处理，客户端不能依赖永久公开 URL。
- MySQL 本地配置启用 ROW 格式 binlog；业务事件仍以事务性 Outbox 为准，不能把 binlog 直接暴露给客户端。
- 站内通知是事实来源，实时连接和系统推送只承担增量提醒。
- 微信与 QQ 身份各自对应独立用户和数据边界；数据库禁止一个用户关联多个登录身份。

## 文档

- [产品与决策基线](./Baseline.md)
- [行动清单](./TODO.md)
- [系统架构](./docs/architecture.md)
- [API 约定](./docs/api-conventions.md)
- [客户端说明](./client/README.md)
- [小程序端说明](./miniapp/README.md)
- [后端说明](./server/README.md)
- [安全策略](./SECURITY.md)
- [贡献指南](./CONTRIBUTING.md)

## 当前里程碑

1. 已完成：仓库分层、内部认证、家庭创建/邀请/成员管理，以及家庭日志发布、私有图片、游标列表、编辑删除、点赞、评论和回复。
2. 下一步：补齐图片后台清理、Mermaid/LaTeX 安全渲染，并实现“注意”内容闭环。
3. 后续：倒数、Outbox、实时同步和系统推送；开放平台资质就绪后替换 Fake Provider。

## 许可证

尚未选择开源许可证。在明确授权前，本仓库内容按保留所有权利处理，不应对外分发或复用。
