# MomenPair Server

MomenPair 后端是独立的 FastAPI 应用。首版采用模块化单体，所有家庭数据都必须经过服务端家庭边界校验。

账号仅允许微信或 QQ 身份，且一个用户只能关联一个身份。两种平台分别创建独立用户，不提供手机号登录、身份绑定、换绑或账号合并。

## 环境要求

- Python 3.12+
- uv
- MySQL 8.4 LTS
- Redis 7.4
- S3 兼容对象存储

## 本地启动

```bash
cp .env.example .env
uv sync --group dev
uv run uvicorn momen_pair.main:app --reload
```

从根目录启动基础设施：

```bash
docker compose up mysql redis minio
```

## API

| 方法 | 路径 | 用途 |
| --- | --- | --- |
| `GET` | `/api/v1/health/live` | 进程存活检查，不访问依赖 |
| `GET` | `/api/v1/health/ready` | 检查 MySQL 与 Redis |
| `GET` | `/api/v1/meta` | 返回服务版本和规划模块 |
| `POST` | `/api/v1/auth/wechat/mobile` | 使用微信一次性 code 登录或注册 |
| `POST` | `/api/v1/auth/qq/mobile` | 使用 QQ 一次性 code 登录或注册 |
| `POST` | `/api/v1/auth/refresh` | 轮换刷新令牌 |
| `GET` | `/api/v1/auth/me` | 查询当前认证用户 |
| `POST` | `/api/v1/auth/logout` | 撤销当前刷新令牌对应的会话 |
| `POST` | `/api/v1/auth/logout-all` | 撤销当前用户的全部会话 |
| `GET` | `/api/v1/families/current` | 查询当前家庭与成员角色 |
| `POST` | `/api/v1/families` | 创建家庭并成为管理员 |
| `POST` | `/api/v1/families/join` | 使用邀请码加入家庭 |
| `GET` | `/api/v1/families/current/members` | 查询当前家庭成员 |
| `PATCH` | `/api/v1/families/current/members/{user_id}` | 修改成员角色 |
| `DELETE` | `/api/v1/families/current/members/{user_id}` | 将成员移出家庭 |
| `POST` | `/api/v1/families/current/leave` | 退出当前家庭 |
| `GET/POST` | `/api/v1/families/current/invitations` | 查询或创建邀请码 |
| `DELETE` | `/api/v1/families/current/invitations/{id}` | 撤销邀请码 |
| `GET/POST` | `/api/v1/logs` | 游标查询或幂等发布家庭日志 |
| `POST` | `/api/v1/logs/media` | 上传、校验并压缩一张待关联图片 |
| `GET` | `/api/v1/logs/media/{id}/content` | 鉴权读取私有图片内容 |
| `DELETE` | `/api/v1/logs/media/{id}` | 删除本人尚未关联的上传 |
| `GET/PATCH/DELETE` | `/api/v1/logs/{id}` | 查询、按版本编辑或软删除日志 |
| `PUT/DELETE` | `/api/v1/logs/{id}/like` | 幂等点赞或取消点赞 |
| `GET/POST` | `/api/v1/logs/{id}/comments` | 查询或幂等发布评论/回复 |
| `PATCH/DELETE` | `/api/v1/logs/{id}/comments/{comment_id}` | 按版本编辑或删除评论 |
| `GET` | `/docs` | 开发环境 OpenAPI UI |

生产环境应设置 `MOMENPAIR_DOCS_ENABLED=false`，并通过网关限制诊断端点访问范围。

`MOMENPAIR_SOCIAL_AUTH_MODE=fake` 仅用于本地内部认证联调。Fake Provider 根据平台和测试 code 生成稳定身份；生产环境会拒绝该配置。接入真实开放平台时由微信/QQ 适配器完成一次性 code 换票，客户端和账号服务契约保持不变。

家庭邀请码使用高熵随机值，服务端只保存 SHA-256 摘要。默认邀请码 24 小时有效且仅可使用一次；管理员可撤销邀请、调整成员角色或移除成员。最后一名管理员在家庭仍有其他成员时必须先转让角色。

日志 API 从认证用户的有效成员关系解析家庭，不接收客户端家庭 ID。创建日志和评论要求 `Idempotency-Key`；编辑和删除要求当前 `expected_version`，冲突返回 `log_version_conflict`。每条日志最多关联 9 张图片；上传入口限制 10 MiB，服务端解码后限制 4000 万像素和最长边 2560 px，移除元数据并统一编码为 WebP。对象保存在 MinIO 私有桶，内容端点会在每次读取时重新校验当前家庭成员关系。日志删除后正文与图片都不可再通过普通 API 访问；点赞由 `(log_id, user_id)` 唯一约束防止重复计数。

## 数据库迁移

```bash
uv run alembic revision --autogenerate -m "describe the schema change"
uv run alembic upgrade head
uv run alembic downgrade -1
```

自动生成后必须人工检查迁移文件，尤其是外键、唯一约束、索引、字符集和数据回填。生产迁移需保持前后版本应用兼容，不应依赖应用与数据库同时瞬时切换。

## 质量检查

```bash
uv run ruff format .
uv run ruff check .
uv run mypy src
uv run pytest
```

## 源码结构

```text
src/momen_pair/
├── api/                    HTTP 路由和传输模型
├── core/                   配置与跨模块应用设置
├── db/                     SQLAlchemy 基类和会话
├── infrastructure/         Redis、对象存储、推送等适配器
├── modules/
│   ├── accounts/           用户和登录身份
│   ├── families/           家庭与成员关系
│   └── logs/               家庭日志、评论与点赞
└── main.py                 应用装配与生命周期
```

新增领域模块时，模块内部承载领域模型、仓储、服务和路由；跨模块交互通过显式服务接口或领域事件，不直接读取其他模块的私有实现。

## 配置

所有环境变量使用 `MOMENPAIR_` 前缀。完整示例见 `.env.example`。生产环境至少需要替换：

- `MOMENPAIR_SECRET_KEY`
- `MOMENPAIR_DATABASE_URL`
- `MOMENPAIR_REDIS_URL`
- `MOMENPAIR_OBJECT_STORAGE_ACCESS_KEY`
- `MOMENPAIR_OBJECT_STORAGE_SECRET_KEY`
- `MOMENPAIR_ALLOWED_HOSTS`
- `MOMENPAIR_CORS_ORIGINS`

密钥不得提交到仓库、输出到日志或传给客户端。
