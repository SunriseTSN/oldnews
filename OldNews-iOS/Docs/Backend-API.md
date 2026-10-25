# OldNews Core 与 iOS 客户端接口约定

基础 URL 示例：`https://oldnews.example.com`

如果服务端启用了鉴权，客户端会把“设置”中的访问令牌作为 `Authorization: Bearer <token>` 发送。DeepSeek API Key 必须保存在 Ubuntu 服务器端，绝不能放进 iOS 包。

## 1. 健康检查

`GET /health`

```json
{ "status": "ok" }
```

任何 2xx 响应均视为网络连接成功。

## 2. 上传附件

`POST /api/files`

Content-Type: `multipart/form-data`，文件字段名为 `file`。

响应：

```json
{
  "id": "file_123",
  "name": "input.png",
  "mime_type": "image/png"
}
```

服务端应限制文件大小、检查 MIME 类型、使用随机存储名，并且不能信任客户端提供的文件名或路径。

## 3. 聊天

`POST /api/chat`

请求：

```json
{
  "message": "把图片转成彩色 ASCII，返回 PNG 和 TXT",
  "conversation_id": null,
  "attachment_ids": ["file_123"]
}
```

响应：

```json
{
  "conversation_id": "conv_abc",
  "reply": "已完成转换。",
  "attachments": [
    {
      "id": "out_456",
      "name": "ascii-color.png",
      "mime_type": "image/png",
      "download_url": "/api/files/out_456/download",
      "preview_url": null
    },
    {
      "id": "out_789",
      "name": "ascii.txt",
      "mime_type": "text/plain",
      "download_url": "/api/files/out_789/download",
      "preview_url": null
    }
  ]
}
```

字段 `reply` 也可以由 `message` 替代，但建议统一使用 `reply`。`attachments` 可以为空数组。相对下载地址以基础 URL 为根解析。

**后端处理建议：** 将用户消息与附件 ID 发给 DeepSeek 的工具调用流程；模型只负责选择已经注册的工具和生成参数，实际程序由受控的插件运行器执行。不要把模型输出直接作为 Shell 命令执行。将结果文件登记到服务端文件表，再把附件元数据返回给客户端。

## 4. 插件列表

`GET /api/plugins`

```json
{
  "plugins": [
    {
      "id": "ascii",
      "name": "ASCII 图像生成",
      "description": "把图片转换为 ASCII 图片并导出 PNG/TXT",
      "icon": "text.alignleft",
      "enabled": true
    }
  ]
}
```

也接受直接返回插件数组。`icon` 应优先采用 SF Symbols 名称；客户端无法识别的图标会回退为通用插件图标。

## 5. 直接运行插件（可选快捷入口）

`POST /api/plugins/{id}/run`

```json
{ "arguments": { "input": "请转换当前上传的图片" } }
```

响应：

```json
{ "output": "任务完成，生成 2 个文件。" }
```

也接受 `message` 字段替代 `output`。生产环境需要权限检查、参数模式校验、超时控制、资源限制和审计日志；高风险动作应要求用户明确确认。

## 6. 状态码和错误

- `200` / `201`：成功。
- `400`：参数或上传文件无效。
- `401` / `403`：访问令牌无效或权限不足。
- `413`：文件太大。
- `429`：限流。
- `5xx`：服务端/插件执行错误。

非 2xx 时，客户端会把响应正文的一小段展示出来供排障。公网部署必须使用 HTTPS，并且下载接口也要校验授权，不能把文件目录直接作为静态公开目录。
