# API 约定

## 路径与版本

- 所有业务接口使用 `/api/v1` 前缀；
- 资源使用复数名词和小写短横线；
- 公开契约以 OpenAPI 文档为准；
- 破坏性修改必须进入新 API 版本，不能复用原字段表达不同含义。

## 请求与响应

- 使用 UTF-8 JSON；日志图片通过鉴权 multipart 接口上传，服务端处理后写入私有对象存储；
- 时间使用 ISO 8601，服务端存储和传输 UTC，事件同时保留 IANA 时区；
- 列表使用不透明游标，响应包含 `items` 和 `next_cursor`；
- 创建和可重试写操作接受 `Idempotency-Key`；
- 可并发编辑的资源返回版本号，并通过条件请求避免静默覆盖。

日志和评论创建请求必须携带 8～64 字符的 `Idempotency-Key`。同一账号重复使用同一键且请求内容一致时返回原资源；内容不同、资源已删除或账号家庭上下文已变化时返回 `idempotency_conflict`。日志与评论编辑在 JSON 中提交 `expected_version`，删除通过查询参数提交；版本落后时返回 `log_version_conflict`。

## 错误格式

错误响应使用稳定机器码，不直接把后端异常文本展示给用户：

```json
{
  "detail": {
    "code": "family_access_denied",
    "message_key": "errors.familyAccessDenied",
    "parameters": {},
    "request_id": "01JEXAMPLE"
  }
}
```

客户端通过 `message_key` 和 `parameters` 生成本地化文案。未经分类的异常返回统一错误码，服务端日志用 `request_id` 关联诊断信息。

## 鉴权与家庭上下文

- 访问令牌放在 `Authorization: Bearer <token>`；
- 刷新令牌只发送给令牌轮换端点；
- 家庭资源路径或令牌上下文可携带家庭 ID，但服务端必须查询有效成员关系；
- 当前家庭管理接口不接收客户端提交的家庭 ID，而是从认证用户的有效成员关系解析；
- 邀请码只在创建响应中返回原值，持久化层仅保存摘要；
- 对象 ID 不具有授权语义，知道 ID 不代表有权访问；
- 管理后台与普通客户端使用不同的权限集合和接口入口。
- 访问令牌为短时签名令牌；刷新令牌为不透明随机值，服务端只保存摘要并在每次刷新时轮换；
- 刷新令牌重放会撤销对应会话，客户端必须原子替换安全存储中的旧令牌；
- 微信和 QQ 身份分别创建独立用户，不能通过另一个平台恢复、绑定或合并。

## 家庭日志

- `GET /logs` 使用 `cursor` 和 `limit`，按 `created_at + id` 倒序返回 `items` 与 `next_cursor`；
- `POST /logs`、`POST /logs/{id}/comments` 使用幂等键；
- `PATCH/DELETE /logs/{id}` 仅允许作者并校验版本；删除采用软删除，普通接口立即隐藏正文；
- `PUT/DELETE /logs/{id}/like` 可安全重复调用，同一用户对同一日志最多一条点赞；
- 回复只提交 `reply_to_comment_id`，服务端计算 `root_comment_id`；客户端统一展示为两层；
- 所有日志、评论和点赞请求都从有效成员关系解析家庭，拒绝跨家庭对象 ID。
- `POST /logs/media` 的 multipart 字段名为 `image`，单文件最大 10 MiB；返回的媒体 ID 通过日志创建或编辑请求的 `media_ids` 关联，每条日志最多 9 张；
- `GET /logs/media/{media_id}/content` 必须携带访问令牌，不返回永久公开对象地址，并在读取时校验当前家庭成员关系；未关联上传仅上传者可读且 24 小时后过期。

## 实时事件

实时事件至少包含：

```json
{
  "event_id": "01JEXAMPLE",
  "family_id": "9ad1c4ac-example",
  "type": "log.updated",
  "resource_id": "662e204a-example",
  "resource_version": 4,
  "occurred_at": "2026-08-17T08:00:00Z"
}
```

客户端按 `event_id` 去重，收到事件后按资源版本拉取最新数据。事件不得携带家庭内容正文、长期凭据或永久图片地址。
