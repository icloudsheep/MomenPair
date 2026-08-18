# API 约定

## 路径与版本

- 所有业务接口使用 `/api/v1` 前缀；
- 资源使用复数名词和小写短横线；
- 公开契约以 OpenAPI 文档为准；
- 破坏性修改必须进入新 API 版本，不能复用原字段表达不同含义。

## 请求与响应

- 使用 UTF-8 JSON；图片通过签名上传直接写入对象存储；
- 时间使用 ISO 8601，服务端存储和传输 UTC，事件同时保留 IANA 时区；
- 列表使用不透明游标，响应包含 `items` 和 `next_cursor`；
- 创建和可重试写操作接受 `Idempotency-Key`；
- 可并发编辑的资源返回版本号，并通过条件请求避免静默覆盖。

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
- 对象 ID 不具有授权语义，知道 ID 不代表有权访问；
- 管理后台与普通客户端使用不同的权限集合和接口入口。
- 访问令牌为短时签名令牌；刷新令牌为不透明随机值，服务端只保存摘要并在每次刷新时轮换；
- 刷新令牌重放会撤销对应会话，客户端必须原子替换安全存储中的旧令牌；
- 微信和 QQ 身份分别创建独立用户，不能通过另一个平台恢复、绑定或合并。

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
